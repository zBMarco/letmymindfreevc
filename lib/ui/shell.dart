import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/sound.dart';
import '../star/star_fx.dart';
import '../store.dart';
import 'celebration.dart';
import 'pages_star_stats.dart';
import 'pages_tasks.dart';
import 'pages_types.dart';
import 'task_sheet.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  final AppStore store;
  const Shell({super.key, required this.store});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  final stamp = ValueNotifier<(String, bool)?>(null);
  StreamSubscription<StarEvent>? _sub;
  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Preview helpers for the browser build only: ?tab=1 opens a tab, ?demo=1 loads sample tasks.
      final q = Uri.base.queryParameters;
      tab = int.tryParse(q['tab'] ?? '') ?? 0;
      if (q['demo'] == '1' && store.tasks.isEmpty) _seedDemo();
      if (q['ft'] != null) fx.debugFlareT = double.tryParse(q['ft']!);
    }
    _sub = store.events.listen(_onEvent);
    store.addListener(_syncFx);
    _syncFx();
  }

  @override
  void dispose() {
    _sub?.cancel();
    store.removeListener(_syncFx);
    super.dispose();
  }

  void _seedDemo() {
    store.addCat('Trabajo', 0xFF7CC8FF);
    store.addCat('Casa', 0xFFFFD27A);
    store.addCat('Trámites', 0xFFFF9F7A);
    final c = store.sortedCats;
    store.addTask(title: 'Ejemplo: entregar reporte', catId: c[0].id, size: 4, due: nowMs() + 5 * 3600000, remind: true);
    store.addTask(title: 'Ejemplo: pagar la luz', catId: c[2].id, size: 3);
    store.addTask(title: 'Ejemplo: lavar ropa', catId: c[1].id, size: 2);
    store.addTask(title: 'Ejemplo: renovar pasaporte', catId: c[2].id, size: 5);
  }

  void _syncFx() {
    fx.sync(load: store.load, nebula: store.star.phase == Phase.nebula, seed: store.star.progress / rebirthNeed);
    SoundEngine.instance.enabled = store.sound;
    final idx = store.star.phase == Phase.nebula ? -1 : starLevels.indexOf(store.level).clamp(0, 3);
    SoundEngine.instance.setHum(idx);
  }

  Future<void> _haptic(List<(int, String)> pattern) async {
    if (!store.haptics) return;
    for (final (delay, kind) in pattern) {
      if (delay > 0) await Future.delayed(Duration(milliseconds: delay));
      switch (kind) {
        case 'heavy':
          HapticFeedback.heavyImpact();
        case 'medium':
          HapticFeedback.mediumImpact();
        case 'light':
          HapticFeedback.lightImpact();
        default:
          HapticFeedback.selectionClick();
      }
    }
  }

  void _onEvent(StarEvent e) {
    switch (e) {
      case TaskCompleted(:final task, :final pctFreed, :final inNebula):
        if (inNebula) {
          SoundEngine.instance.play('chime');
          _haptic([(0, 'medium'), (120, 'light')]);
        } else {
          fx.flare();
          SoundEngine.instance.play('flare');
          _haptic([(0, 'heavy'), (90, 'heavy'), (160, 'medium'), (220, 'light')]);
        }
        final lines = celebrationLines[task.size] ?? celebrationLines[1]!;
        showCelebration(
          context,
          big: inNebula ? '+1 chispa' : '−$pctFreed% carga',
          line: inNebula ? 'Tu nueva estrella se forma: ${store.star.phase == Phase.nebula ? store.star.progress : rebirthNeed}/$rebirthNeed' : lines[Random().nextInt(lines.length)],
          small: 'Tardaste ${fmtDur(task.takenMs)}${task.activeMs > 0 ? ' enfocado' : ''} · ${store.doneToday.length} hoy${inNebula ? '' : ' · tu estrella: ${store.level.name}'}',
        );
      case Supernova():
        setState(() => tab = 1);
        fx.explode();
        SoundEngine.instance.play('boom');
        _haptic([(0, 'heavy'), (60, 'heavy'), (60, 'heavy'), (120, 'heavy'), (200, 'medium'), (300, 'light'), (400, 'light')]);
        Future.delayed(const Duration(milliseconds: 700), () => stamp.value = ('¡Supernova!', false));
        Future.delayed(const Duration(milliseconds: 3400), () => stamp.value = null);
      case Rebirth():
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          setState(() => tab = 1);
          fx.rebirth();
          SoundEngine.instance.play('rebirth');
          _haptic([(0, 'light'), (300, 'medium'), (500, 'heavy')]);
          Future.delayed(const Duration(milliseconds: 1100), () => stamp.value = ('¡Renació! #${store.star.rebirths}', true));
          Future.delayed(const Duration(milliseconds: 3800), () => stamp.value = null);
        });
    }
  }

  void _openSheet([Task? edit]) {
    showTaskSheet(context, store, edit: edit);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final lvl = store.level;
        final nebula = store.star.phase == Phase.nebula;
        final pages = [
          TasksPage(store: store, onEdit: _openSheet, onAdd: () => _openSheet()),
          StarPage(store: store, stamp: stamp),
          StatsPage(store: store, onGoTasks: () => setState(() => tab = 0)),
          TypesPage(store: store),
        ];
        return Scaffold(
          backgroundColor: C.bg,
          body: Stack(children: [
            Positioned.fill(child: SkyBackground(tint: Color(lvl.color), nebula: nebula)),
            SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _Header(store: store, onTap: () => setState(() => tab = 1)),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(a), child: child),
                    ),
                    child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
                  ),
                ),
              ]),
            ),
            if (tab == 0 || tab == 1)
              Positioned(
                right: 20,
                bottom: bottomInset + 92,
                child: _Fab(color: Color(lvl.color), onTap: () => _openSheet()),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: bottomInset + 10,
              child: _NavBar(tab: tab, color: Color(lvl.color), onTap: (i) {
                if (store.haptics) HapticFeedback.selectionClick();
                setState(() => tab = i);
              }),
            ),
          ]),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final AppStore store;
  final VoidCallback onTap;
  const _Header({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lvl = store.level;
    final color = Color(lvl.color);
    final nebula = store.star.phase == Phase.nebula;
    final load = store.load;
    final frac = nebula ? store.star.progress / rebirthNeed : load.clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Glass(
        blur: true,
        padding: const EdgeInsets.fromLTRB(6, 8, 16, 8),
        child: Row(children: [
          const SizedBox(width: 72, height: 72, child: ClipOval(child: StarView(detail: 0, zoom: 2.1))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 600),
                    style: sora(21, w: FontWeight.w600, color: color).copyWith(shadows: [Shadow(color: color.withValues(alpha: .6), blurRadius: 18)]),
                    child: Text(lvl.name),
                  ),
                ),
                Text(nebula ? '${store.star.progress}/$rebirthNeed' : '${(load * 100).round()}%', style: mono(17, w: FontWeight.w500)),
              ]),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(children: [
                  Container(height: 8, color: Colors.white.withValues(alpha: .09)),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    widthFactor: frac.toDouble(),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(colors: [C.sky, nebula ? const Color(0xFFD7A8FF) : color]),
                        boxShadow: [BoxShadow(color: color, blurRadius: 12)],
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 7),
              Text(nebula ? 'Termina tareas para encender tu nueva estrella' : lvl.hint,
                  style: sora(12, color: C.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Fab extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;
  const _Fab({required this.color, required this.onTap});
  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? .9 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: const Alignment(-.3, -.4), colors: [Colors.white, widget.color, Color.lerp(widget.color, Colors.black, .3)!], stops: const [0, .55, 1]),
              boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .6), blurRadius: 30), const BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: const Icon(Icons.add_rounded, size: 32, color: C.ink, semanticLabel: 'Nueva tarea'),
          ),
        ),
      );
}

class _NavBar extends StatelessWidget {
  final int tab;
  final Color color;
  final ValueChanged<int> onTap;
  const _NavBar({required this.tab, required this.color, required this.onTap});

  static const _items = [
    (Icons.format_list_bulleted_rounded, 'Tareas'),
    (Icons.wb_sunny_outlined, 'Estrella'),
    (Icons.insights_rounded, 'Progreso'),
    (Icons.public_rounded, 'Tipos'),
  ];

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Glass(
            blur: true,
            radius: 26,
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: tab == i ? Colors.white.withValues(alpha: .1) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_items[i].$1, size: 22, color: tab == i ? color : C.faint, shadows: tab == i ? [Shadow(color: color, blurRadius: 10)] : null),
                        const SizedBox(height: 3),
                        Text(_items[i].$2, style: sora(11, w: FontWeight.w500, color: tab == i ? color : C.faint)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
