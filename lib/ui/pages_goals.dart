import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import 'pages_tasks.dart';
import 'theme.dart';

const _bottomPad = 170.0;
const fire = Color(0xFFFFB86B);
const _wd = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

String _daysWord(int n) => n == 1 ? 'día' : 'días';
String _tasksWord(int n) => n == 1 ? 'tarea' : 'tareas';

class GoalsPage extends StatefulWidget {
  final AppStore store;
  final VoidCallback onAdd;
  final void Function(Goal) onEdit;
  const GoalsPage({super.key, required this.store, required this.onAdd, required this.onEdit});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  String? openId;
  bool showAchieved = false;
  AppStore get store => widget.store;

  void _delete(Goal g) {
    final removed = store.deleteGoal(g.id);
    if (removed == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 90),
        backgroundColor: const Color(0xE6181A38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99), side: const BorderSide(color: C.line2)),
        content: Text('Meta borrada.', style: sora(14)),
        action: SnackBarAction(label: 'Deshacer', textColor: const Color(0xFFFFD58A), onPressed: () => store.restoreGoal(removed)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final active = store.activeGoals;
    final achieved = store.achievedGoals;
    final children = <Widget>[
      Text('Mis metas', style: sora(28, w: FontWeight.w600, ls: -.5)),
      Text('Lo que quieres lograr, siempre a la vista. Tu racha suma uno por cada tarea que completas.', style: sora(14, color: C.faint, height: 1.45)),
      _StreakHero(store: store),
      _NextReward(store: store),
      if (active.isEmpty)
        Glass(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(achieved.isEmpty ? '¿Qué quieres lograr?' : 'Todas tus metas están cumplidas.', style: sora(21, w: FontWeight.w600, height: 1.2)),
            const SizedBox(height: 10),
            Text('Escribe tus metas y para qué las quieres. Cada día que avances en una, márcala: así nunca se te olvidan. Y cada tarea que completas suma a tu racha y dibuja constelaciones en tu cielo.',
                style: sora(15, color: C.muted, height: 1.45)),
            const SizedBox(height: 16),
            Pill(achieved.isEmpty ? 'Escribir mi primera meta' : 'Nueva meta', primary: true, onTap: widget.onAdd),
          ]),
        )
      else ...[
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('EN CAMINO · ${active.length}', style: label())),
        for (final g in active)
          GoalCard(
            key: ValueKey(g.id),
            goal: g,
            store: store,
            open: openId == g.id,
            onToggle: () => setState(() => openId = openId == g.id ? null : g.id),
            onEdit: () => widget.onEdit(g),
            onDelete: () => _delete(g),
          ),
        Text('Toca el círculo cuando hoy avances en esa meta. Toca la tarjeta para ver opciones.', style: sora(13, color: C.faint, height: 1.45)),
      ],
      if (achieved.isNotEmpty) ...[
        GestureDetector(
          onTap: () => setState(() => showAchieved = !showAchieved),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line2)),
            child: Row(children: [
              const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFFD58A)),
              const SizedBox(width: 8),
              Expanded(child: Text('Metas logradas · ${achieved.length}', style: sora(14, w: FontWeight.w500, color: C.muted))),
              Text(showAchieved ? 'Ocultar' : 'Ver', style: mono(12, color: C.muted)),
            ]),
          ),
        ),
        if (showAchieved)
          for (final g in achieved)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x33FFD58A))),
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded, size: 22, color: Color(0xFFFFD58A), shadows: [Shadow(color: Color(0xFFFFD58A), blurRadius: 12)]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.title, style: sora(15, w: FontWeight.w500)),
                    Text('Lograda ${fmtDate(g.achievedAt!)} · ${g.days.length} ${_daysWord(g.days.length)} de esfuerzo', style: mono(11, color: C.faint)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Volver a ponerla en camino',
                  onPressed: () => store.reopenGoal(g.id),
                  icon: const Icon(Icons.undo_rounded, size: 18, color: C.faint),
                ),
              ]),
            ),
      ],
      _Sky(store: store),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomPad),
      itemCount: children.length,
      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 6 : 14),
      itemBuilder: (_, i) => children[i],
    );
  }
}

/* ============================== streak ============================== */

class _StreakHero extends StatelessWidget {
  final AppStore store;
  const _StreakHero({required this.store});

  @override
  Widget build(BuildContext context) {
    final streak = store.streak;
    final best = store.bestStreak;
    final today = store.streakToday;
    final days = store.streakDays;
    final hot = streak > 0;
    final now = DateTime.now();
    final String status;
    final Color statusColor;
    if (today) {
      final n = days[dayKey(nowMs())] ?? 0;
      status = 'Hoy llevas $n ${_tasksWord(n)}. Cada una más suma a tu racha.';
      statusColor = C.ok;
    } else if (streak > 0) {
      status = 'Completa una tarea hoy para no perder tu racha de $streak ${_tasksWord(streak)}.';
      statusColor = C.warn;
    } else if (best > 0) {
      status = 'Tu récord es de $best ${_tasksWord(best)}. Empieza otra racha hoy.';
      statusColor = C.muted;
    } else {
      status = 'Completa una tarea y enciende tu primera racha. Cada tarea suma uno; si pasa un día sin ninguna, vuelve a cero.';
      statusColor = C.muted;
    }
    return Glass(
      border: hot ? fire.withValues(alpha: .35) : null,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _Flame(on: hot, today: today),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: streak.toDouble()),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text('${v.round()}',
                    style: mono(46, w: FontWeight.w600, color: hot ? fire : C.faint).copyWith(height: 1, shadows: hot ? [Shadow(color: fire.withValues(alpha: .7), blurRadius: 24)] : null)),
              ),
              const SizedBox(height: 4),
              Text('${_tasksWord(streak)} de racha'.toUpperCase(), style: sora(11, w: FontWeight.w600, color: C.muted, ls: 1.2)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('RÉCORD', style: sora(10, w: FontWeight.w600, color: C.faint, ls: 1)),
            Text('$best', style: mono(20, w: FontWeight.w500, color: const Color(0xFFFFD58A))),
            const SizedBox(height: 6),
            Text('CONSTELACIONES', style: sora(10, w: FontWeight.w600, color: C.faint, ls: 1)),
            Text('${store.unlockedRewards.length}/${rewards.length}', style: mono(20, w: FontWeight.w500, color: C.sky)),
          ]),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(builder: (_) {
                // the last 7 days, today on the right
                final d = DateTime(now.year, now.month, now.day - 6 + i, 12);
                final k = dayKey(d.millisecondsSinceEpoch);
                final isToday = i == 6;
                final n = days[k] ?? 0;
                final on = n > 0;
                return Column(children: [
                  Text(isToday ? 'HOY' : _wd[d.weekday - 1], style: sora(11, w: FontWeight.w600, color: isToday ? C.text : C.faint)),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? fire : Colors.white.withValues(alpha: .05),
                      border: Border.all(color: on ? fire : (isToday ? C.line2 : C.line), width: isToday && !on ? 1.6 : 1),
                      boxShadow: on ? [BoxShadow(color: fire.withValues(alpha: .6), blurRadius: 14)] : null,
                    ),
                    alignment: Alignment.center,
                    // how many tasks you did that day
                    child: on ? Text('$n', style: mono(n > 99 ? 10 : 13, w: FontWeight.w700, color: C.ink)) : null,
                  ),
                ]);
              }),
            ),
        ]),
        const SizedBox(height: 14),
        Text(status, style: sora(13.5, w: FontWeight.w500, color: statusColor, height: 1.35)),
      ]),
    );
  }
}

class _Flame extends StatefulWidget {
  final bool on, today;
  const _Flame({required this.on, required this.today});
  @override
  State<_Flame> createState() => _FlameState();
}

class _FlameState extends State<_Flame> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) {
          final v = Curves.easeInOut.transform(c.value);
          final col = widget.on ? fire : C.faint;
          return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [col.withValues(alpha: widget.on ? .35 : .08), col.withValues(alpha: 0)]),
              boxShadow: widget.on ? [BoxShadow(color: fire.withValues(alpha: .25 + .2 * v), blurRadius: 20 + 14 * v)] : null,
            ),
            child: Transform.scale(
              scale: widget.on ? 1 + .08 * v : 1,
              child: Icon(Icons.local_fire_department_rounded, size: 40, color: col, shadows: widget.on ? [Shadow(color: fire, blurRadius: 16 + 8 * v)] : null),
            ),
          );
        },
      );
}

class _NextReward extends StatelessWidget {
  final AppStore store;
  const _NextReward({required this.store});

  @override
  Widget build(BuildContext context) {
    final next = store.nextReward;
    final streak = store.streak;
    if (next == null) {
      return Glass(
        child: Text('Completaste todas las constelaciones. Tu cielo está lleno. Sigue así.', style: sora(15, w: FontWeight.w500, color: const Color(0xFFFFE08A))),
      );
    }
    final idx = rewards.indexOf(next);
    final prev = idx == 0 ? 0 : rewards[idx - 1].tasks;
    final frac = ((streak - prev) / (next.tasks - prev)).clamp(0.0, 1.0);
    final left = next.tasks - streak;
    final color = Color(next.color);
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(children: [
        SizedBox(width: 104, height: 104, child: Constellation(reward: next, lit: (frac * next.pts.length).floor(), pulseNext: true)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PRÓXIMA RECOMPENSA', style: label()),
            const SizedBox(height: 4),
            Text(next.name, style: sora(22, w: FontWeight.w600, color: color).copyWith(shadows: [Shadow(color: color.withValues(alpha: .5), blurRadius: 16)])),
            const SizedBox(height: 2),
            Text('${left == 1 ? 'Falta' : 'Faltan'} $left ${_tasksWord(left)} · se gana con ${next.tasks}', style: mono(12, color: C.muted)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Stack(children: [
                Container(height: 7, color: Colors.white.withValues(alpha: .08)),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  widthFactor: max(frac, .02),
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(colors: [fire, color]),
                      boxShadow: [BoxShadow(color: color, blurRadius: 10)],
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Cada tarea completada enciende una estrella.', style: sora(12, color: C.faint)),
          ]),
        ),
      ]),
    );
  }
}

/* ============================== goal card ============================== */

class GoalCard extends StatefulWidget {
  final Goal goal;
  final AppStore store;
  final bool open;
  final VoidCallback onToggle, onEdit, onDelete;
  const GoalCard({super.key, required this.goal, required this.store, required this.open, required this.onToggle, required this.onEdit, required this.onDelete});
  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> with SingleTickerProviderStateMixin {
  late final AnimationController pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    pop.dispose();
    super.dispose();
  }

  void _check() {
    final on = widget.store.toggleGoalToday(widget.goal.id);
    if (on) {
      pop.forward(from: 0);
    } else if (widget.store.haptics) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final color = Color(g.color);
    final done = g.doneToday;
    final now = DateTime.now();
    String? targetText;
    Color targetColor = C.faint;
    if (g.target != null) {
      final t = DateTime.fromMillisecondsSinceEpoch(g.target!);
      final daysLeft = DateTime(t.year, t.month, t.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      if (daysLeft > 1) {
        targetText = 'para el ${fmtDate(g.target!)} · faltan $daysLeft días';
        if (daysLeft <= 7) targetColor = C.warn;
      } else if (daysLeft == 1) {
        targetText = 'para mañana';
        targetColor = C.warn;
      } else if (daysLeft == 0) {
        targetText = 'para hoy';
        targetColor = C.hot;
      } else {
        targetText = 'la fecha era el ${fmtDate(g.target!)}';
        targetColor = C.hot;
      }
    }
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: done ? color.withValues(alpha: .08) : C.glass,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: done ? color.withValues(alpha: .45) : C.line),
          boxShadow: done ? [BoxShadow(color: color.withValues(alpha: .15), blurRadius: 30)] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 5), child: Orb(color: color, size: 14)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: sora(17, w: FontWeight.w600, height: 1.25)),
                if (g.why.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Para qué: ${g.why}', style: sora(13.5, color: C.muted, height: 1.4).copyWith(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 4, children: [
                  Text('cumplida ${g.days.length} ${_daysWord(g.days.length)}', style: mono(12, color: C.faint)),
                  if (targetText != null) Text(targetText, style: mono(12, color: targetColor)),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            _DayCheck(done: done, color: color, pop: pop, onTap: _check),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 13; i >= 0; i--) ...[
              Expanded(
                child: Builder(builder: (_) {
                  final on = g.days.contains(dayKey(DateTime(now.year, now.month, now.day - i, 12).millisecondsSinceEpoch));
                  return Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: on ? color : Colors.white.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: on ? [BoxShadow(color: color.withValues(alpha: .6), blurRadius: 6)] : null,
                    ),
                  );
                }),
              ),
              if (i > 0) const SizedBox(width: 3),
            ],
          ]),
          const SizedBox(height: 4),
          Text('últimas 2 semanas', style: sora(10.5, color: C.faint)),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: widget.open
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      Pill('¡La logré!', small: true, icon: Icons.emoji_events_rounded, color: const Color(0xFFFFD58A), onTap: () => widget.store.achieveGoal(g.id)),
                      Pill('Editar', small: true, icon: Icons.edit_rounded, onTap: widget.onEdit),
                      Pill('Borrar', small: true, icon: Icons.delete_outline_rounded, color: C.hot, onTap: widget.onDelete),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}

class _DayCheck extends StatelessWidget {
  final bool done;
  final Color color;
  final AnimationController pop;
  final VoidCallback onTap;
  const _DayCheck({required this.done, required this.color, required this.pop, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: done ? 'Desmarcar hoy' : 'Hoy cumplí esta meta',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedBuilder(
            animation: pop,
            builder: (_, child) {
              final v = pop.value;
              final ring = v > 0 && v < 1;
              return SizedBox(
                width: 56,
                height: 56,
                child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                  if (ring)
                    Container(
                      width: 52 + 40 * v,
                      height: 52 + 40 * v,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 1 - v), width: 3 * (1 - v) + .5)),
                    ),
                  Transform.scale(scale: 1 + .25 * sin(v * pi), child: child),
                ]),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? color : Colors.white.withValues(alpha: .04),
                border: Border.all(color: done ? color : C.line2, width: 1.5),
                boxShadow: done ? [BoxShadow(color: color.withValues(alpha: .8), blurRadius: 22)] : null,
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: C.ink, size: 30)
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_rounded, size: 20, color: C.muted),
                      Text('HOY', style: sora(9, w: FontWeight.w600, color: C.muted, ls: .8)),
                    ]),
            ),
          ),
        ),
      );
}

/* ============================== trophy sky ============================== */

class _Sky extends StatelessWidget {
  final AppStore store;
  const _Sky({required this.store});

  @override
  Widget build(BuildContext context) {
    final best = store.bestStreak;
    return Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TU CIELO · CONSTELACIONES GANADAS', style: label()),
        const SizedBox(height: 6),
        Text('Cada racha que alcanzas te da una constelación para siempre, y aparece brillando en el cielo de fondo de la app.',
            style: sora(13, color: C.faint, height: 1.45)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .78,
          children: [
            for (final r in rewards)
              Builder(builder: (_) {
                final got = r.tasks <= best;
                final color = Color(r.color);
                return GestureDetector(
                  onTap: got ? () => showRewardUnlock(context, r, replay: true) : null,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: got ? color.withValues(alpha: .07) : Colors.white.withValues(alpha: .025),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: got ? color.withValues(alpha: .35) : C.line),
                    ),
                    child: Column(children: [
                      Expanded(child: Opacity(opacity: got ? 1 : .35, child: Constellation(reward: r, lit: got ? r.pts.length : 0))),
                      const SizedBox(height: 4),
                      Text(got ? r.name : '???', style: sora(12, w: FontWeight.w600, color: got ? color : C.faint), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (!got) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.lock_rounded, size: 10, color: C.faint)),
                        Text('${r.tasks} tareas', style: mono(10, color: C.faint)),
                      ]),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ]),
    );
  }
}

/* ============================== constellation drawing ============================== */

/// Draws a [Reward]'s constellation with its first [lit] stars on. [draw] (0..1) animates
/// the stars and lines appearing one after another.
class Constellation extends StatefulWidget {
  final Reward reward;
  final int lit;
  final double draw;
  final bool pulseNext;
  const Constellation({super.key, required this.reward, required this.lit, this.draw = 1, this.pulseNext = false});
  @override
  State<Constellation> createState() => _ConstellationState();
}

class _ConstellationState extends State<Constellation> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.pulseNext) _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _pulse;
    if (p == null) return CustomPaint(painter: ConstellationPainter(widget.reward, widget.lit, widget.draw, 0), size: Size.infinite);
    return AnimatedBuilder(
      animation: p,
      builder: (_, _) => CustomPaint(painter: ConstellationPainter(widget.reward, widget.lit, widget.draw, p.value, pulseNext: true), size: Size.infinite),
    );
  }
}

class ConstellationPainter extends CustomPainter {
  final Reward r;
  final int lit;
  final double draw;
  final double pulse;
  final bool pulseNext;
  final double alpha;
  ConstellationPainter(this.r, this.lit, this.draw, this.pulse, {this.pulseNext = false, this.alpha = 1});

  static void paintInto(Canvas canvas, Rect box, Reward r, {int? lit, double draw = 1, double alpha = 1, double pulse = 0, bool pulseNext = false}) {
    final color = Color(r.color);
    final n = r.pts.length;
    final on = lit ?? n;
    final pad = box.shortestSide * .1;
    final inner = box.deflate(pad);
    Offset at(int i) => Offset(inner.left + r.pts[i].$1 * inner.width, inner.top + r.pts[i].$2 * inner.height);
    // how far along the animation each star is (stars appear one after another)
    double reveal(int i) => ((draw * (n + 1)) - i).clamp(0.0, 1.0);
    final s = box.shortestSide;

    // faint guide lines for the shape still to be earned
    final guide = Paint()
      ..color = Colors.white.withValues(alpha: .07 * alpha)
      ..strokeWidth = max(.8, s * .008);
    for (final (a, b) in r.edges) {
      if (a >= on || b >= on) canvas.drawLine(at(a), at(b), guide);
    }
    final line = Paint()
      ..strokeWidth = max(1.0, s * .014)
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in r.edges) {
      if (a >= on || b >= on) continue;
      final k = min(reveal(a), reveal(b));
      if (k <= 0) continue;
      line.color = color.withValues(alpha: .55 * alpha);
      canvas.drawLine(at(a), Offset.lerp(at(a), at(b), Curves.easeOutCubic.transform(k))!, line);
    }
    final glow = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, max(2, s * .04));
    final dot = Paint();
    for (var i = 0; i < n; i++) {
      final p = at(i);
      if (i < on) {
        final k = Curves.elasticOut.transform(reveal(i));
        if (k <= 0) continue;
        final rad = max(1.6, s * .035) * k;
        glow.color = color.withValues(alpha: .8 * alpha);
        canvas.drawCircle(p, rad * 2.2, glow);
        dot.color = Colors.white.withValues(alpha: alpha);
        canvas.drawCircle(p, rad, dot);
      } else if (pulseNext && i == on) {
        final rad = max(1.6, s * .03) * (1 + .5 * pulse);
        glow.color = color.withValues(alpha: (.15 + .35 * pulse) * alpha);
        canvas.drawCircle(p, rad * 2, glow);
        dot.color = color.withValues(alpha: (.35 + .4 * pulse) * alpha);
        canvas.drawCircle(p, rad * .7, dot);
      } else {
        dot.color = Colors.white.withValues(alpha: .18 * alpha);
        canvas.drawCircle(p, max(1.2, s * .018), dot);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) => paintInto(canvas, Offset.zero & size, r, lit: lit, draw: draw, alpha: alpha, pulse: pulse, pulseNext: pulseNext);

  @override
  bool shouldRepaint(covariant ConstellationPainter old) => old.r != r || old.lit != lit || old.draw != draw || old.pulse != pulse;
}

/* ============================== reward unlocked ============================== */

OverlayEntry? _rewardEntry;

void showRewardUnlock(BuildContext context, Reward r, {bool replay = false}) {
  _rewardEntry?.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _RewardOverlay(
      reward: r,
      replay: replay,
      onDone: () {
        if (_rewardEntry == entry) {
          entry.remove();
          _rewardEntry = null;
        }
      },
    ),
  );
  _rewardEntry = entry;
  Overlay.of(context).insert(entry);
}

class _RewardOverlay extends StatefulWidget {
  final Reward reward;
  final bool replay;
  final VoidCallback onDone;
  const _RewardOverlay({required this.reward, required this.replay, required this.onDone});
  @override
  State<_RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<_RewardOverlay> with TickerProviderStateMixin {
  late final AnimationController intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  late final AnimationController out = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final AnimationController twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  final _sparks = List.generate(60, (i) {
    final r = Random(i * 31 + 7);
    return (r.nextDouble() * pi * 2, 80 + r.nextDouble() * 260, 1.5 + r.nextDouble() * 3.5, r.nextDouble());
  });

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 9), _close);
  }

  void _close() {
    if (!mounted || out.isAnimating || out.isCompleted) return;
    out.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    intro.dispose();
    out.dispose();
    twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    final color = Color(r.color);
    return GestureDetector(
      onTap: () {
        if (intro.value > .35) _close();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([intro, out, twinkle]),
        builder: (context, _) {
          final v = intro.value;
          final fade = (1 - out.value) * Curves.easeOut.transform((v / .12).clamp(0.0, 1.0));
          final draw = Curves.easeInOut.transform(((v - .1) / .55).clamp(0.0, 1.0));
          final text = Curves.easeOutBack.transform(((v - .55) / .3).clamp(0.0, 1.0));
          final burst = ((v - .6) / .4).clamp(0.0, 1.0);
          return Opacity(
            opacity: fade,
            child: Stack(children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [color.withValues(alpha: .22), const Color(0xE6020310)], radius: .9),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: CustomPaint(painter: _Sparks(_sparks, burst, twinkle.value, color))),
              Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Opacity(
                        opacity: text,
                        child: Text(widget.replay ? 'CONSTELACIÓN GANADA' : '¡NUEVA CONSTELACIÓN!', style: sora(13, w: FontWeight.w700, color: color, ls: 2.2)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: CustomPaint(painter: ConstellationPainter(r, r.pts.length, draw, 0)),
                      ),
                      const SizedBox(height: 8),
                      Transform.scale(
                        scale: .7 + .3 * text,
                        child: Opacity(
                          opacity: text.clamp(0.0, 1.0),
                          child: Column(children: [
                            Text(r.name, textAlign: TextAlign.center, style: sora(42, w: FontWeight.w600, color: Colors.white, ls: -1).copyWith(shadows: [Shadow(color: color, blurRadius: 30)])),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: fire.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: fire.withValues(alpha: .5))),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.local_fire_department_rounded, size: 18, color: fire),
                                const SizedBox(width: 6),
                                Text('Racha de ${r.tasks} tareas', style: mono(15, w: FontWeight.w500, color: fire)),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            Text(r.line, textAlign: TextAlign.center, style: sora(17, w: FontWeight.w500, height: 1.35)),
                            const SizedBox(height: 10),
                            Text('Ya brilla en el cielo de tu app.', textAlign: TextAlign.center, style: sora(13, color: C.muted)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Opacity(opacity: ((v - .85) / .15).clamp(0.0, 1.0), child: Text('Toca para seguir', style: mono(12, color: C.faint))),
                    ]),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Sparks extends CustomPainter {
  final List<(double, double, double, double)> sparks;
  final double k, tw;
  final Color color;
  _Sparks(this.sparks, this.k, this.tw, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (k <= 0) return;
    final c = Offset(size.width / 2, size.height * .42);
    final e = Curves.easeOutCubic.transform(k);
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
    for (final (a, dist, s, ph) in sparks) {
      final pos = c + Offset(cos(a), sin(a)) * dist * (.3 + e);
      final twk = .5 + .5 * sin((tw + ph) * pi * 2);
      p.color = Color.lerp(Colors.white, color, ph)!.withValues(alpha: (.3 + .6 * twk) * min(1, k * 3));
      canvas.drawCircle(pos, s * (.6 + .4 * twk), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Sparks old) => true;
}

/* ============================== goal sheet ============================== */

Future<void> showGoalSheet(BuildContext context, AppStore store, {Goal? edit}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x80020310),
    builder: (_) => _GoalSheet(store: store, edit: edit),
  );
}

class _GoalSheet extends StatefulWidget {
  final AppStore store;
  final Goal? edit;
  const _GoalSheet({required this.store, this.edit});
  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final title = TextEditingController(text: widget.edit?.title ?? '');
  late final why = TextEditingController(text: widget.edit?.why ?? '');
  late int color = widget.edit?.color ?? catPalette[widget.store.goals.length % catPalette.length];
  late bool hasTarget = widget.edit?.target != null;
  late DateTime target = widget.edit?.target != null ? DateTime.fromMillisecondsSinceEpoch(widget.edit!.target!) : DateTime.now().add(const Duration(days: 30));
  String? error;

  @override
  void dispose() {
    title.dispose();
    why.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.store.haptics) HapticFeedback.selectionClick();
  }

  void _save() {
    final text = title.text.trim();
    if (text.isEmpty) {
      setState(() => error = 'Escribe tu meta.');
      return;
    }
    final s = widget.store;
    final t = hasTarget ? DateTime(target.year, target.month, target.day, 23, 59).millisecondsSinceEpoch : null;
    if (widget.edit != null) {
      s.updateGoal(widget.edit!.id, title: text, why: why.text.trim(), color: color, target: t);
    } else {
      s.addGoal(title: text, why: why.text.trim(), color: color, target: t);
      if (s.haptics) HapticFeedback.lightImpact();
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    var picked = target;
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(color: Color(0xFF14162E), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              CupertinoButton(child: Text('Listo', style: sora(16, w: FontWeight.w600, color: Theme.of(context).colorScheme.primary)), onPressed: () => Navigator.of(ctx).pop()),
            ]),
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(brightness: Brightness.dark),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: target,
                  minimumDate: DateTime.now().subtract(const Duration(days: 1)),
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
    setState(() => target = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
            decoration: const BoxDecoration(color: Color(0xC7141630), border: Border(top: BorderSide(color: C.line2))),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 22 + MediaQuery.of(context).padding.bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 12),
                Text(widget.edit != null ? 'Editar meta' : '¿Qué quieres lograr?', style: sora(24, w: FontWeight.w600)),
                const SizedBox(height: 14),
                GlassField(controller: title, hint: 'Ej. Hacer ejercicio, aprender inglés', onSubmit: (_) => _save()),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: sora(13, color: C.hot))),
                const SizedBox(height: 18),
                Text('PARA QUÉ (TE LO RECUERDA CADA DÍA)', style: label()),
                const SizedBox(height: 8),
                GlassField(controller: why, hint: 'Ej. Sentirme con energía y dormir mejor', lines: 2),
                const SizedBox(height: 18),
                Text('COLOR', style: label()),
                const SizedBox(height: 10),
                Row(children: [
                  for (final c in catPalette)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          _tap();
                          setState(() => color = c);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 2)),
                          child: Orb(color: Color(c), size: 26),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('Fecha para lograrla', style: sora(16, w: FontWeight.w500))),
                      Toggle(value: hasTarget, onChanged: (v) {
                        _tap();
                        setState(() => hasTarget = v);
                      }),
                    ]),
                    if (hasTarget) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                          child: Row(children: [
                            const Icon(Icons.event_rounded, size: 18, color: C.muted),
                            const SizedBox(width: 10),
                            Text(fmtDate(target.millisecondsSinceEpoch), style: mono(15)),
                          ]),
                        ),
                      ),
                    ] else
                      Text('Opcional. Sin fecha, la meta queda abierta.', style: sora(12.5, color: C.faint)),
                  ]),
                ),
                const SizedBox(height: 20),
                Center(child: Pill(widget.edit != null ? 'Guardar cambios' : 'Agregar meta', primary: true, onTap: _save)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
