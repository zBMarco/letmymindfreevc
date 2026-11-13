import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shared animation state for every star on screen (header mini + observatory).
/// The store says *what* happened; this turns it into time-based shader uniforms.
enum StarMode { star, exploding, nebula, reborn }

class StarUniforms {
  double load = .3, radius = .16, explode = 0, nebula = 0, seed = 0, flash = 0, ringR = 0, ringA = 0, flareT = -1, flareA = 0;
  double offX = 0, offY = 0, shakeX = 0, shakeY = 0;
}

class StarFx extends ChangeNotifier {
  StarFx._();
  static final instance = StarFx._();

  static ui.FragmentProgram? program;
  static ui.FragmentProgram? planetProgram;
  static Future<void> loadShader() async {
    try {
      program = await ui.FragmentProgram.fromAsset('shaders/star.frag');
    } catch (e) {
      debugPrint('Shader no disponible: $e');
    }
    try {
      planetProgram = await ui.FragmentProgram.fromAsset('shaders/planet.frag');
    } catch (e) {
      debugPrint('Shader de planetas no disponible: $e');
    }
  }

  final _rnd = Random();
  StarMode mode = StarMode.star;
  double targetLoad = .3;
  double seedProgress = 0;
  double _sL = .3;
  Duration _last = Duration.zero;
  double _t0 = 0, _shrink = -10, _ring = -10, _flare = -10, _flareA = 0;
  double time = 0;
  bool reduced = false;
  /// Browser preview only: freezes a flare at this progress (0..1).
  double? debugFlareT;

  /// Smoothed load the star is drawn with (radius and color follow this, not the raw store value).
  double get smoothLoad => _sL;

  /// Progress (0..1) of the current explosion or rebirth; 0 in the other modes.
  double get phaseK => switch (mode) {
        StarMode.exploding => ((time - _t0) / 3.2).clamp(0.0, 1.0),
        StarMode.reborn => ((time - _t0) / 2.6).clamp(0.0, 1.0),
        _ => 0.0,
      };

  /// Light the star casts on its planets (same blackbody ramp as the shader's starColor).
  static List<double> lightColor(double l) {
    const c = [
      [0.60, 0.74, 1.00],
      [1.00, 0.88, 0.66],
      [1.00, 0.60, 0.28],
      [1.00, 0.33, 0.13],
      [0.85, 0.15, 0.06],
    ];
    List<double> mix(int i, double k) => [for (var j = 0; j < 3; j++) c[i][j] + (c[i + 1][j] - c[i][j]) * k.clamp(0.0, 1.0)];
    final List<double> out;
    if (l < .35) {
      out = mix(0, l / .35);
    } else if (l < .6) {
      out = mix(1, (l - .35) / .25);
    } else if (l < .85) {
      out = mix(2, (l - .6) / .25);
    } else {
      out = mix(3, (l - .85) / .3);
    }
    // planets see the star a bit whiter than it looks in the sky
    return [for (final v in out) .35 + .75 * v];
  }

  void sync({required double load, required bool nebula, required double seed}) {
    targetLoad = load.clamp(0, 1.15);
    seedProgress = seed;
    if (nebula && mode == StarMode.star) mode = StarMode.nebula;
    if (!nebula && mode == StarMode.nebula) mode = StarMode.star;
  }

  void flare() {
    _flare = time;
    _flareA = _rnd.nextDouble() * pi * 2;
    _ring = time;
    _shrink = time;
  }

  void explode() {
    mode = StarMode.exploding;
    _t0 = time;
  }

  void rebirth() {
    mode = StarMode.reborn;
    _t0 = time;
    _sL = min(_sL, .3);
  }

  /// Advance once per frame (call from any ticker; extra calls in the same frame are ignored).
  void tick(Duration elapsed) {
    if (elapsed == _last) return;
    final dt = _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    time += dt.clamp(0, .1);
    _sL += (targetLoad - _sL) * (1 - exp(-dt * 1.8));
  }

  StarUniforms uniforms() {
    final u = StarUniforms();
    final t = time;
    final L = _sL.clamp(0.0, 1.15);
    var r = .16 * (.8 + .55 * min(L, 1.1));
    r *= 1 + .012 * sin(t * (1.2 + L * 3.5));
    final sk = (1 - (t - _shrink) / .7).clamp(0.0, 1.0);
    r *= 1 - .07 * sin(sk * pi);
    if (L > .78 && mode == StarMode.star && !reduced) {
      final amp = (L - .78) * .006;
      u.offX = (_rnd.nextDouble() - .5) * amp;
      u.offY = (_rnd.nextDouble() - .5) * amp;
    }
    u.load = L;
    u.radius = r;
    switch (mode) {
      case StarMode.exploding:
        final e = (t - _t0) / 3.2;
        u.radius = r * (1 + (e / .08).clamp(0.0, 1.0) * .6);
        u.explode = e.clamp(0.0, 1.0);
        u.nebula = ((e - .2) / .8).clamp(0.0, 1.0);
        u.flash = exp(-(e - .09).abs() * 30) * .9;
        if (e >= 1) mode = StarMode.nebula;
      case StarMode.nebula:
        u.nebula = 1;
        u.radius = 0;
        u.seed = seedProgress;
      case StarMode.reborn:
        final k = (t - _t0) / 2.6;
        u.nebula = (1 - k * 1.4).clamp(0.0, 1.0);
        u.seed = 1;
        final g = ((k - .3) / .7).clamp(0.0, 1.0);
        final back = 1 + 2.4 * pow(g - 1, 3) + 1.4 * pow(g - 1, 2);
        u.radius = r * max(0.0, back);
        u.flash = exp(-(k - .3).abs() * 18) * .8;
        if (k >= 1) mode = StarMode.star;
      case StarMode.star:
        break;
    }
    final rk = (t - _ring) / 1.2;
    if (rk >= 0 && rk < 1) {
      u.ringR = r * (1 + rk * 1.8);
      u.ringA = (1 - rk) * .9;
    }
    final ft = (t - _flare) / 2.6;
    if (ft >= 0 && ft < 1) {
      u.flareT = ft;
      u.flareA = _flareA;
      if (!reduced) {
        final amp = max(0.0, 1 - ft / .18) * .006;
        u.shakeX = (_rnd.nextDouble() - .5) * amp;
        u.shakeY = (_rnd.nextDouble() - .5) * amp;
        u.flash = max(u.flash, exp(-ft * 25) * .25);
      }
    }
    if (debugFlareT != null) {
      u.flareT = debugFlareT!;
      u.flareA = .8;
    }
    return u;
  }
}

/// Draws the star with the fragment shader. [detail] 1 = observatory, 0 = small header star.
/// [zoom] scales the star inside the box (the mini view crops tighter).
class StarView extends StatefulWidget {
  final double detail;
  final double zoom;
  const StarView({super.key, this.detail = 1, this.zoom = 1});
  @override
  State<StarView> createState() => _StarViewState();
}

class _StarViewState extends State<StarView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      StarFx.instance.tick(e);
      _repaint.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    StarFx.instance.reduced = MediaQuery.of(context).disableAnimations;
    final prog = StarFx.program;
    if (prog == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color(0xFFFFF4D6), Color(0xFFFFB020), Color(0x00FF8000)], stops: [0, .45, 1]),
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(painter: _StarPainter(prog.fragmentShader(), _repaint, widget.detail, widget.zoom), size: Size.infinite),
    );
  }
}

class _StarPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double detail, zoom;
  _StarPainter(this.shader, Listenable repaint, this.detail, this.zoom) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final u = StarFx.instance.uniforms();
    final s = shader;
    var i = 0;
    s.setFloat(i++, size.width);
    s.setFloat(i++, size.height);
    s.setFloat(i++, StarFx.instance.time * (StarFx.instance.reduced ? .3 : 1));
    s.setFloat(i++, u.load);
    s.setFloat(i++, u.radius);
    s.setFloat(i++, u.explode);
    s.setFloat(i++, u.nebula);
    s.setFloat(i++, u.seed);
    s.setFloat(i++, u.flash);
    s.setFloat(i++, u.ringR);
    s.setFloat(i++, u.ringA);
    s.setFloat(i++, u.flareT);
    s.setFloat(i++, u.flareA);
    s.setFloat(i++, u.offX);
    s.setFloat(i++, u.offY);
    s.setFloat(i++, u.shakeX);
    s.setFloat(i++, u.shakeY);
    s.setFloat(i++, detail);
    s.setFloat(i++, zoom);
    canvas.drawRect(Offset.zero & size, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => true;
}
