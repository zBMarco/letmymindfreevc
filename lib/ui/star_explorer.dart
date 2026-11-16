import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../star/star_fx.dart';
import '../store.dart';
import 'theme.dart';

/// Opens the full-screen explorer: the star in deep space, turn it, zoom in, pan.
void openStarExplorer(BuildContext context, AppStore store, {double zoom = 1}) {
  if (store.haptics) HapticFeedback.mediumImpact();
  Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 550),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, _, _) => StarExplorer(store: store, zoom: zoom),
    transitionsBuilder: (_, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: c, child: ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(c), child: child));
    },
  ));
}

/// Same effective temperature ramp the shader uses (Kelvin).
double starTempK(double l) {
  double mix(double a, double b, double k) => a + (b - a) * k.clamp(0.0, 1.0);
  if (l < .35) return mix(9500, 5800, l / .35);
  if (l < .6) return mix(5800, 4400, (l - .35) / .25);
  if (l < .85) return mix(4400, 3400, (l - .6) / .25);
  return mix(3400, 2700, (l - .85) / .3);
}

/// Harvard spectral class (O B A F G K M) with its 0–9 subclass, hotter = lower number.
String spectralClass(double t) {
  const bands = [('O', 30000.0, 50000.0), ('B', 10000.0, 30000.0), ('A', 7500.0, 10000.0), ('F', 6000.0, 7500.0), ('G', 5200.0, 6000.0), ('K', 3700.0, 5200.0), ('M', 2400.0, 3700.0)];
  for (final (l, lo, hi) in bands) {
    if (t >= lo) return '$l${((hi - t) / (hi - lo) * 10).floor().clamp(0, 9)}';
  }
  return 'M9';
}

String _kindOf(double t) {
  if (t >= 7500) return 'Estrella blanca-azulada';
  if (t >= 6000) return 'Estrella blanco-amarilla';
  if (t >= 5200) return 'Enana amarilla, como el Sol';
  if (t >= 3700) return 'Enana naranja';
  return 'Estrella roja';
}

String _thousands(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class StarExplorer extends StatefulWidget {
  final AppStore store;

  /// Starting zoom, relative to the default view.
  final double zoom;
  const StarExplorer({super.key, required this.store, this.zoom = 1});
  @override
  State<StarExplorer> createState() => _StarExplorerState();
}

class _StarExplorerState extends State<StarExplorer> with SingleTickerProviderStateMixin {
  static const _baseZoom = 1.8, _minZoom = .9, _maxZoom = 16.0;
  final cam = StarCamera()
    ..space = true
    ..zoom = _baseZoom
    ..pitch = .18;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  // gesture state
  double _startZoom = 1;
  Offset _lastFocal = Offset.zero;
  double _vYaw = 0, _vPitch = 0;
  bool _dragging = false;
  bool autoSpin = true;
  bool showInfo = false;
  bool hint = true;
  double _idle = 0;

  // reset animation
  double? _resetT;
  late double _fromYaw, _fromPitch, _fromZoom, _fromPx, _fromPy;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    cam.zoom = (_baseZoom * widget.zoom).clamp(_minZoom, _maxZoom);
    cam.detail = 1 + ((cam.zoom - 2.4) / 2.4).clamp(0.0, 1.0);
    _zoomLevel = cam.zoom < 2.6 ? 0 : (cam.zoom < 6 ? 1 : 2);
    _ticker = createTicker(_tick)..start();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => hint = false);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _px => 1 / max(1.0, MediaQuery.of(context).size.shortestSide);

  void _tick(Duration e) {
    final dt = _last == Duration.zero ? .016 : ((e - _last).inMicroseconds / 1e6).clamp(0.0, .05);
    _last = e;
    final rt = _resetT;
    if (rt != null) {
      final t = min(1.0, rt + dt / .7);
      final k = Curves.easeInOutCubic.transform(t);
      double lerp(double a, double b) => a + (b - a) * k;
      cam
        ..yaw = lerp(_fromYaw, 0)
        ..pitch = lerp(_fromPitch, .18)
        ..zoom = lerp(_fromZoom, _baseZoom)
        ..panX = lerp(_fromPx, 0)
        ..panY = lerp(_fromPy, 0);
      _resetT = t >= 1 ? null : t;
      _sync();
      return;
    }
    if (_dragging) return;
    // inertia after a flick
    cam.yaw += _vYaw * dt;
    cam.pitch = (cam.pitch + _vPitch * dt).clamp(-1.35, 1.35);
    final damp = exp(-dt * 2.6);
    _vYaw *= damp;
    _vPitch *= damp;
    _idle += dt;
    // turns slowly on its own while you just look at it
    if (autoSpin && _idle > 1.2) cam.yaw += dt * .06 * min(1.0, (_idle - 1.2) / 2);
  }

  void _sync() {
    cam.detail = 1 + ((cam.zoom - 2.4) / 2.4).clamp(0.0, 1.0);
    final lvl = cam.zoom < 2.6 ? 0 : (cam.zoom < 6 ? 1 : 2);
    if (lvl != _zoomLevel) setState(() => _zoomLevel = lvl);
  }

  int _zoomLevel = 0;

  void _onScaleStart(ScaleStartDetails d) {
    _dragging = true;
    _resetT = null;
    _startZoom = cam.zoom;
    _lastFocal = d.focalPoint;
    _vYaw = _vPitch = 0;
    _idle = 0;
    if (hint) setState(() => hint = false);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final delta = d.focalPoint - _lastFocal;
    _lastFocal = d.focalPoint;
    if (d.pointerCount >= 2) {
      cam.zoom = (_startZoom * d.scale).clamp(_minZoom, _maxZoom);
      _pan(delta);
    } else {
      // one finger turns the star; when zoomed in a lot the motion slows down so you can aim
      final k = .0065 / sqrt(cam.zoom / _baseZoom).clamp(1.0, 4.0);
      cam.yaw += delta.dx * k;
      cam.pitch = (cam.pitch - delta.dy * k).clamp(-1.35, 1.35);
      final dt = 1 / 60;
      _vYaw = _vYaw * .5 + delta.dx * k / dt * .5;
      _vPitch = _vPitch * .5 - delta.dy * k / dt * .5;
    }
    _sync();
  }

  void _pan(Offset delta) {
    final u = _px / cam.zoom;
    final lim = .45;
    cam.panX = (cam.panX - delta.dx * u).clamp(-lim, lim);
    cam.panY = (cam.panY + delta.dy * u).clamp(-lim, lim);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _dragging = false;
    _idle = 0;
    if (d.pointerCount > 0) {
      _vYaw = _vPitch = 0;
    }
    _vYaw = _vYaw.clamp(-4.0, 4.0);
    _vPitch = _vPitch.clamp(-4.0, 4.0);
  }

  void _onWheel(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      cam.zoom = (cam.zoom * exp(-e.scrollDelta.dy * .0015)).clamp(_minZoom, _maxZoom);
      _idle = 0;
      _sync();
    }
  }

  void _reset() {
    if (store.haptics) HapticFeedback.selectionClick();
    _fromYaw = cam.yaw % (2 * pi);
    if (_fromYaw > pi) _fromYaw -= 2 * pi;
    cam.yaw = _fromYaw;
    _fromPitch = cam.pitch;
    _fromZoom = cam.zoom;
    _fromPx = cam.panX;
    _fromPy = cam.panY;
    _vYaw = _vPitch = 0;
    _resetT = 0;
  }

  void _zoomBy(double f) {
    if (store.haptics) HapticFeedback.selectionClick();
    _resetT = null;
    cam.zoom = (cam.zoom * f).clamp(_minZoom, _maxZoom);
    _idle = 0;
    _sync();
  }

  String _caption(double load, bool nebula) {
    if (nebula) return 'Nebulosa: gas y polvo de tu supernova. Aquí se está formando tu nueva estrella.';
    final spots = load > .5;
    return switch (_zoomLevel) {
      0 => 'La corona: gas a más de un millón de grados que escapa de la superficie. Los arcos rojos del borde son protuberancias.',
      1 => spots
          ? 'Manchas estelares: zonas más frías (y oscuras) donde el campo magnético frena el calor. Aparecen cuando tu estrella está estresada.'
          : 'La fotosfera, la superficie visible. Las zonas brillantes cerca del borde son fáculas, más calientes que su alrededor.',
      _ => 'Granulación: cada celda es una burbuja de plasma caliente que sube, se enfría y se hunde por las líneas oscuras. En el Sol cada una mide como un país.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final nebula = store.star.phase == Phase.nebula;
          final lvl = store.level;
          final color = Color(lvl.color);
          final load = store.load;
          final temp = starTempK(fx.smoothLoad);
          return Stack(children: [
            Positioned.fill(
              child: Listener(
                onPointerSignal: _onWheel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  onDoubleTap: _reset,
                  child: StarView(camera: cam),
                ),
              ),
            ),
            // soft shade so the titles read over a bright surface
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: pad.top + 110,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xB3000000), Color(0x00000000)])),
                ),
              ),
            ),
            // top bar
            Positioned(
              top: pad.top + 8,
              left: 14,
              right: 14,
              child: Row(children: [
                _RoundBtn(icon: Icons.close_rounded, label: 'Cerrar', onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tu estrella', style: sora(13, w: FontWeight.w500, color: C.muted)),
                    Text(nebula ? 'Nebulosa' : lvl.name,
                        style: sora(22, w: FontWeight.w600, color: color).copyWith(shadows: [Shadow(color: color.withValues(alpha: .6), blurRadius: 18)])),
                  ]),
                ),
                _RoundBtn(
                  icon: Icons.threesixty_rounded,
                  label: autoSpin ? 'Dejar de girar' : 'Girar sola',
                  on: autoSpin,
                  onTap: () => setState(() => autoSpin = !autoSpin),
                ),
                const SizedBox(width: 8),
                _RoundBtn(icon: Icons.center_focus_strong_rounded, label: 'Centrar', onTap: _reset),
              ]),
            ),
            // zoom buttons (handy with a mouse, and for one hand)
            Positioned(
              right: 14,
              top: MediaQuery.of(context).size.height * .38,
              child: Column(children: [
                _RoundBtn(icon: Icons.add_rounded, label: 'Acercar', onTap: () => _zoomBy(1.6)),
                const SizedBox(height: 8),
                _RoundBtn(icon: Icons.remove_rounded, label: 'Alejar', onTap: () => _zoomBy(1 / 1.6)),
              ]),
            ),
            // hint
            Positioned(
              left: 0,
              right: 0,
              top: pad.top + 76,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: hint ? 1 : 0,
                  duration: const Duration(milliseconds: 600),
                  child: Center(
                    child: Glass(
                      blur: true,
                      radius: 99,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Text('Arrastra para girar · pellizca para acercar · doble toque para centrar', textAlign: TextAlign.center, style: sora(12, color: C.text)),
                    ),
                  ),
                ),
              ),
            ),
            // bottom: what you are looking at + data sheet
            Positioned(
              left: 14,
              right: 14,
              bottom: pad.bottom + 14,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: GestureDetector(
                    onTap: () => setState(() => showInfo = !showInfo),
                    child: Glass(
                      blur: true,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.bottomCenter,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [
                            Text(['VISTA LEJANA', 'SUPERFICIE', 'DE CERCA'][_zoomLevel], style: label()),
                            const Spacer(),
                            Text('×${(cam.zoom / _baseZoom).toStringAsFixed(1)}', style: mono(12, color: C.muted)),
                            const SizedBox(width: 10),
                            Icon(showInfo ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 20, color: C.muted),
                          ]),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(_caption(load, nebula), key: ValueKey('$_zoomLevel$nebula${load > .5}'), style: sora(13.5, color: C.text, height: 1.4)),
                          ),
                          if (showInfo && !nebula) ...[
                            const SizedBox(height: 14),
                            Text('FICHA ESTELAR', style: label()),
                            const SizedBox(height: 8),
                            _Row('Tipo', _kindOf(temp)),
                            _Row('Clase espectral', spectralClass(temp)),
                            _Row('Temperatura superficial', '${_thousands((temp / 50).round() * 50)} K'),
                            _Row('Carga', '${(load * 100).round()}%'),
                            _Row('Manchas', load > .5 ? 'Sí, por el estrés' : 'Sin manchas'),
                            _Row('Supernovas · renacimientos', '${store.star.supernovas} · ${store.star.rebirths}'),
                            const SizedBox(height: 8),
                            Text(
                              'El color sale de la temperatura con la ley de Planck: mientras más carga, más fría y roja. '
                              'Si sueltas tareas, se calienta y se vuelve blanca-azulada. El Sol es G2, 5,800 K.',
                              style: sora(12, color: C.faint, height: 1.45),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String k, v;
  const _Row(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(k, style: sora(13, color: C.muted))),
          Text(v, style: mono(13, w: FontWeight.w500)),
        ]),
      );
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.label, required this.onTap, this.on = false});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Glass(
            blur: true,
            radius: 99,
            tint: on ? Colors.white.withValues(alpha: .22) : null,
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22, color: C.text),
          ),
        ),
      );
}
