import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../star/star_fx.dart';
import '../store.dart';
import 'celebration.dart';
import 'pages_goals.dart';
import 'pages_star_stats.dart';
import 'star_explorer.dart';
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
      // ?streak=30 fakes a streak of that many days ending today (to preview the flame colors).
      final st = int.tryParse(q['streak'] ?? '');
      if (st != null && st > 0) {
        final d = DateTime.now();
        for (var i = 0; i < st; i++) {
          store.debugStreakDays.add(dayKey(DateTime(d.year, d.month, d.day - i, 12).millisecondsSinceEpoch));
        }
      }
      if (q['ft'] != null) fx.debugFlareT = double.tryParse(q['ft']!);
      final rw = int.tryParse(q['reward'] ?? '');
      if (rw != null && rw >= 0 && rw < rewards.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => showRewardUnlock(context, rewards[rw]));
      }
      final ex = double.tryParse(q['explore'] ?? '');
      if (ex != null) WidgetsBinding.instance.addPostFrameCallback((_) => openStarExplorer(context, store, zoom: ex));
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
    store.addCat('Salud', 0xFF8EF0B8);
    store.addCat('Dinero', 0xFFC3A6FF);
    final c2 = store.sortedCats;
    final pres = store.addTask(title: 'Ejemplo: armar presentación', catId: c2[0].id, size: 1, due: nowMs() + 2 * 86400000);
    for (final s in ['Índice', 'Gráficas', 'Ensayar']) {
      store.addSub(pres.id, s);
    }
    final med = store.addTask(title: 'Ejemplo: chequeo médico', catId: c2[3].id, size: 1);
    store.addSub(med.id, 'Agendar cita');
    final g1 = store.addGoal(title: 'Ejemplo: hacer ejercicio', why: 'Tener más energía y dormir mejor', color: 0xFF8EF0B8);
    final g2 = store.addGoal(title: 'Ejemplo: aprender inglés', why: 'Conseguir un mejor trabajo', color: 0xFF7CC8FF, target: nowMs() + 40 * 86400000);
    final d = DateTime.now();
    for (var i = 1; i <= 8; i++) {
      (i.isEven ? g1 : g2).days.add(dayKey(DateTime(d.year, d.month, d.day - i, 12).millisecondsSinceEpoch));
    }
    // finished tasks become rocks in the asteroid belt
    for (var i = 0; i < 40; i++) {
      final t = store.addTask(title: 'Ejemplo: hecha $i', catId: c2[i % c2.length].id, size: 1 + i % 4);
      store.complete(t.id);
    }
  }

  void _syncFx() {
    fx.sync(load: store.load, nebula: store.star.phase == Phase.nebula, seed: store.star.progress / rebirthNeed);
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
      case TaskCompleted(:final task, :final pctFreed, :final inNebula, :final streak, :final unlocked):
        if (unlocked != null) {
          // this task reached a new constellation: that's the celebration
          fx.flare();
          _haptic([(0, 'light'), (200, 'medium'), (200, 'heavy'), (300, 'heavy'), (400, 'medium')]);
          showRewardUnlock(context, unlocked);
          return;
        }
        if (inNebula) {
          _haptic([(0, 'medium'), (120, 'light')]);
        } else {
          fx.flare();
          _haptic([(0, 'heavy'), (90, 'heavy'), (160, 'medium'), (220, 'light')]);
        }
        final lines = celebrationLines[task.size] ?? celebrationLines[1]!;
        final next = store.nextReward;
        final left = next == null ? 0 : next.days - streak;
        showCelebration(
          context,
          // first task of the day: the streak grows
          title: streak > 0 ? (streak == 1 ? '¡Racha encendida!' : '¡$streak días de racha!') : '¡Hecho!',
          color: streak > 0 ? fire : C.ok,
          big: inNebula ? '+1 chispa' : '−$pctFreed% carga',
          line: inNebula ? 'Tu nueva estrella se forma: ${store.star.phase == Phase.nebula ? store.star.progress : rebirthNeed}/$rebirthNeed' : lines[Random().nextInt(lines.length)],
          small: streak > 0 && next != null
              ? 'Tardaste ${fmtDur(task.takenMs)} · faltan $left ${left == 1 ? 'día' : 'días'} para ${next.name}'
              : 'Tardaste ${fmtDur(task.takenMs)}${task.activeMs > 0 ? ' enfocado' : ''} · ${store.doneToday.length} hoy${inNebula ? '' : ' · tu estrella: ${store.level.name}'}',
        );
      case Supernova():
        setState(() => tab = 1);
        fx.explode();
        _haptic([(0, 'heavy'), (60, 'heavy'), (60, 'heavy'), (120, 'heavy'), (200, 'medium'), (300, 'light'), (400, 'light')]);
        Future.delayed(const Duration(milliseconds: 700), () => stamp.value = ('¡Supernova!', false));
        Future.delayed(const Duration(milliseconds: 3400), () => stamp.value = null);
      case GoalChecked(:final goal, :final firstToday):
        if (firstToday) {
          // first goal kept today
          fx.flare();
          _haptic([(0, 'heavy'), (110, 'medium'), (120, 'light')]);
          showCelebration(
            context,
            title: '¡Meta de hoy!',
            color: fire,
            big: goal.title,
            line: goalCheers[Random().nextInt(goalCheers.length)],
            small: 'Tu racha crece con cada día que completas una tarea.',
          );
        } else {
          // another goal on a day that already counted
          _haptic([(0, 'medium'), (90, 'light')]);
        }
      case GoalAchieved(:final goal):
        fx.flare();
        _haptic([(0, 'heavy'), (90, 'heavy'), (160, 'heavy'), (220, 'medium'), (300, 'light')]);
        showCelebration(
          context,
          title: '¡Meta lograda!',
          color: const Color(0xFFFFD58A),
          big: goal.title,
          line: 'Lo dijiste y lo hiciste.',
          small: '${goal.days.length} ${goal.days.length == 1 ? 'día' : 'días'} de esfuerzo · desde ${fmtDate(goal.createdAt)}',
        );
      case Rebirth():
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          setState(() => tab = 1);
          fx.rebirth();
          _haptic([(0, 'light'), (300, 'medium'), (500, 'heavy')]);
          Future.delayed(const Duration(milliseconds: 1100), () => stamp.value = ('¡Renació! #${store.star.rebirths}', true));
          Future.delayed(const Duration(milliseconds: 3800), () => stamp.value = null);
        });
    }
  }

  void _openSheet([Task? edit]) {
    showTaskSheet(context, store, edit: edit);
  }

  void _openGoal([Goal? edit]) {
    showGoalSheet(context, store, edit: edit);
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
          GoalsPage(store: store, onAdd: () => _openGoal(), onEdit: _openGoal),
          StatsPage(store: store, onGoTasks: () => setState(() => tab = 0)),
          TypesPage(store: store),
        ];
        return Scaffold(
          backgroundColor: C.bg,
          body: Stack(children: [
            Positioned.fill(child: SkyBackground(tint: Color(lvl.color), nebula: nebula, constellations: store.unlockedRewards)),
            SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _Header(store: store, onTap: () => setState(() => tab = 1), onStreak: tab == 0 ? () => setState(() => tab = 2) : null),
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
            if (tab <= 2)
              Positioned(
                right: 20,
                bottom: bottomInset + 92,
                child: _Fab(color: tab == 2 ? fire : Color(lvl.color), label: tab == 2 ? 'Nueva meta' : 'Nueva tarea', onTap: () => tab == 2 ? _openGoal() : _openSheet()),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: bottomInset + 10,
              child: _NavBar(tab: tab, color: Color(lvl.color), goalsPending: store.activeGoals.isNotEmpty && !store.goalDoneToday, onTap: (i) {
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

  /// Shows the streak badge (on the Tasks tab) and opens Goals when tapped.
  final VoidCallback? onStreak;
  const _Header({required this.store, required this.onTap, this.onStreak});

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
          Semantics(
            button: true,
            label: 'Explorar mi estrella',
            child: GestureDetector(
              onTap: () => openStarExplorer(context, store),
              child: const SizedBox(width: 72, height: 72, child: ClipOval(child: StarView(detail: 0, zoom: 2.1))),
            ),
          ),
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
                if (onStreak != null) ...[
                  _StreakBadge(days: store.streak, lit: store.streakToday, onTap: onStreak!),
                  const SizedBox(width: 10),
                ],
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

/// Your streak (days with at least one task done). The flame changes color as it grows
/// (see [flameTiers]), glows and flickers more the longer it is, and stays dim until you finish a task today.
class _StreakBadge extends StatefulWidget {
  final int days;
  final bool lit;
  final VoidCallback onTap;
  const _StreakBadge({required this.days, required this.lit, required this.onTap});
  @override
  State<_StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<_StreakBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  int get _tier => flameTierOf(widget.days);
  bool get _alive => widget.lit && _tier >= 1;

  @override
  void initState() {
    super.initState();
    _syncAnim();
  }

  @override
  void didUpdateWidget(_StreakBadge old) {
    super.didUpdateWidget(old);
    _syncAnim();
  }

  void _syncAnim() {
    if (_alive && !_flicker.isAnimating) {
      _flicker.repeat();
    } else if (!_alive && _flicker.isAnimating) {
      _flicker.stop();
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = _tier;
    final t = flameTiers[i];
    final lit = widget.lit;
    final dim = lit ? 1.0 : .5;
    final base = Color(t.base).withValues(alpha: dim);
    final tip = Color(t.tip).withValues(alpha: dim);
    final heat = i / (flameTiers.length - 1); // 0..1, how strong the glow and flicker are
    final days = widget.days;
    return Semantics(
      button: true,
      label: 'Racha de constancia: $days ${days == 1 ? 'día' : 'días'}, ${t.name}${lit ? '' : ', aún no cumples hoy'}',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _flicker,
          builder: (context, _) {
            final a = _flicker.value * 2 * pi;
            // two mixed waves read as a real flicker instead of a steady pulse
            final f = _alive ? (sin(a) * .6 + sin(a * 3 + 1.3) * .4) : 0.0;
            final glow = lit && i > 0 ? (.25 + .45 * heat) * (1 + .25 * f) : 0.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
              decoration: BoxDecoration(
                gradient: lit && i > 0 ? LinearGradient(colors: [base.withValues(alpha: .10 + .12 * heat), tip.withValues(alpha: .06)]) : null,
                color: lit && i > 0 ? null : Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: lit && i > 0 ? tip.withValues(alpha: .55) : C.line),
                boxShadow: glow > 0 ? [BoxShadow(color: base.withValues(alpha: glow.clamp(0, 1)), blurRadius: 10 + 14 * heat)] : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Transform.scale(
                  scale: 1 + (.05 + .07 * heat) * f,
                  alignment: Alignment.bottomCenter,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [base, tip],
                    ).createShader(r),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: Colors.white,
                      shadows: glow > 0 ? [Shadow(color: tip, blurRadius: 6 + 8 * heat)] : null,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text('$days', style: mono(14, w: FontWeight.w600, color: lit && i > 0 ? Color.lerp(tip, Colors.white, .15)! : C.muted)),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _Fab extends StatefulWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _Fab({required this.color, required this.label, required this.onTap});
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
            child: Icon(Icons.add_rounded, size: 32, color: C.ink, semanticLabel: widget.label),
          ),
        ),
      );
}

class _NavBar extends StatelessWidget {
  final int tab;
  final Color color;
  final bool goalsPending;
  final ValueChanged<int> onTap;
  const _NavBar({required this.tab, required this.color, required this.goalsPending, required this.onTap});

  static const _items = [
    (Icons.format_list_bulleted_rounded, 'Tareas'),
    (Icons.wb_sunny_outlined, 'Estrella'),
    (Icons.local_fire_department_rounded, 'Metas'),
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
                        Stack(clipBehavior: Clip.none, children: [
                          Icon(_items[i].$1, size: 22, color: tab == i ? color : C.faint, shadows: tab == i ? [Shadow(color: color, blurRadius: 10)] : null),
                          if (i == 2 && goalsPending)
                            Positioned(
                              right: -3,
                              top: -1,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: fire, boxShadow: [BoxShadow(color: fire, blurRadius: 6)]),
                              ),
                            ),
                        ]),
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
