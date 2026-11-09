import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/reminders.dart';
import '../services/sound.dart';
import '../store.dart';
import 'theme.dart';

const _bottomPad = 170.0;

class TasksPage extends StatefulWidget {
  final AppStore store;
  final void Function(Task) onEdit;
  final VoidCallback onAdd;
  const TasksPage({super.key, required this.store, required this.onEdit, required this.onAdd});
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String? filter;
  String? openId;
  bool showLater = false;
  AppStore get store => widget.store;

  void _delete(Task t) {
    final removed = store.delete(t.id);
    if (openId == t.id) openId = null;
    if (removed == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 90),
        backgroundColor: const Color(0xE6181A38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99), side: const BorderSide(color: C.line2)),
        content: Text('Tarea borrada.', style: sora(14)),
        action: SnackBarAction(label: 'Deshacer', textColor: const Color(0xFFFFD58A), onPressed: () => store.restore(removed)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (filter != null && !store.cats.containsKey(filter)) filter = null;
    final pending = store.pending(filter: filter);
    final cats = store.sortedCats;
    final all = store.tasks.values;
    final nebula = store.star.phase == Phase.nebula;
    final load = store.load;
    final upcoming = store.upcoming;
    final doneToday = store.doneToday;

    final children = <Widget>[
      if (nebula) HopeBanner(store: store),
      if (!nebula && load > .75)
        _Warn('Tu estrella está al límite (${(load * 100).round()}%). Suelta algo chico hoy para calmarla.'),
      if (cats.isNotEmpty)
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            Chip2('Todas', on: filter == null, count: '${all.where((t) => t.isVisible).length}', onTap: () => setState(() => filter = null)),
            for (final c in cats) ...[
              const SizedBox(width: 8),
              Chip2(c.name, on: filter == c.id, dot: Color(c.color), count: '${all.where((t) => t.isVisible && t.catId == c.id).length}', onTap: () => setState(() => filter = c.id)),
            ],
          ]),
        ),
      if (pending.isNotEmpty) ...[
        for (final t in pending)
          TaskCard(
            key: ValueKey(t.id),
            task: t,
            store: store,
            open: openId == t.id,
            onToggle: () => setState(() => openId = openId == t.id ? null : t.id),
            onEdit: () => widget.onEdit(t),
            onDelete: () => _delete(t),
          ),
        Text('Desliza a la derecha para completar · a la izquierda para borrar · toca para ver detalles.', style: sora(13, color: C.faint, height: 1.45)),
      ] else if (all.isEmpty)
        _Empty(
          title: '¿Qué le está pesando a tu estrella?',
          body: 'Anota lo que te estresa, una cosa a la vez. Cada tarea suma carga a tu estrella; al terminarla, la estrella se calma.',
          action: Pill('Anotar la primera', primary: true, onTap: widget.onAdd),
        )
      else if (all.any((t) => t.isVisible))
        const _Empty(title: 'Nada pendiente en este tipo.', body: 'Cambia de filtro o agrega algo nuevo.')
      else
        const _Empty(title: 'Lista limpia. Tu estrella está en calma.', body: 'Si aparece algo nuevo, anótalo y suéltalo.'),
      if (upcoming.isNotEmpty) ...[
        GestureDetector(
          onTap: () => setState(() => showLater = !showLater),
          child: _Dashed(child: Row(children: [
            Expanded(child: Text('Próximas repetitivas · ${upcoming.length}', style: sora(14, w: FontWeight.w500, color: C.muted))),
            Text(showLater ? 'Ocultar' : 'Ver', style: mono(12, color: C.muted)),
          ])),
        ),
        if (showLater)
          for (final t in upcoming)
            _Dashed(child: Row(children: [
              Expanded(child: Text(t.title, style: sora(14, color: C.muted))),
              Text('aparece ${fmtDay(t.showFrom!).toLowerCase()}', style: mono(12, color: C.faint)),
            ])),
      ],
      if (doneToday.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(top: 6), child: Text('SOLTADO HOY · ${doneToday.length}', style: label())),
        for (final t in doneToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .06))),
            child: Row(children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: C.ok, boxShadow: [BoxShadow(color: C.ok.withValues(alpha: .5), blurRadius: 10)]),
                child: const Icon(Icons.check_rounded, size: 14, color: C.ink),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(t.title, style: sora(15, color: C.muted).copyWith(decoration: TextDecoration.lineThrough, decorationColor: C.muted))),
              Text(fmtDur(t.takenMs), style: mono(12, color: C.faint)),
            ]),
          ),
      ],
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomPad),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => children[i],
    );
  }
}

class HopeBanner extends StatelessWidget {
  final AppStore store;
  const HopeBanner({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final p = store.star.progress;
    final left = rebirthNeed - p;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [C.violet.withValues(alpha: .18), C.sky.withValues(alpha: .1)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.violet.withValues(alpha: .35)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tu estrella explotó, pero de la nebulosa nace otra.', style: sora(16, w: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Termina $left ${left == 1 ? 'tarea más' : 'tareas más'} para encenderla.', style: sora(14, color: C.muted)),
          ]),
        ),
        const SizedBox(width: 12),
        for (var i = 0; i < rebirthNeed; i++)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: i < p ? null : Border.all(color: C.line2),
                gradient: i < p ? const RadialGradient(center: Alignment(-.2, -.2), colors: [Colors.white, Color(0xFF9FD8FF), Color(0xFF7B6BFF)]) : null,
                boxShadow: i < p ? const [BoxShadow(color: Color(0xFF9FD8FF), blurRadius: 14)] : null,
              ),
            ),
          ),
      ]),
    );
  }
}

class _Warn extends StatefulWidget {
  final String text;
  const _Warn(this.text);
  @override
  State<_Warn> createState() => _WarnState();
}

class _WarnState extends State<_Warn> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: C.hot.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.hot.withValues(alpha: .4)),
            boxShadow: [BoxShadow(color: C.hot.withValues(alpha: .3 * c.value), blurRadius: 28)],
          ),
          child: child,
        ),
        child: Text(widget.text, style: sora(15, w: FontWeight.w500, color: const Color(0xFFFFC9C1))),
      );
}

class _Empty extends StatelessWidget {
  final String title, body;
  final Widget? action;
  const _Empty({required this.title, required this.body, this.action});
  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: sora(21, w: FontWeight.w600, height: 1.2)),
          const SizedBox(height: 10),
          Text(body, style: sora(15, color: C.muted, height: 1.45)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

class _Dashed extends StatelessWidget {
  final Widget child;
  const _Dashed({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line2)),
        child: child,
      );
}

/* ============================== task card ============================== */

class TaskCard extends StatefulWidget {
  final Task task;
  final AppStore store;
  final bool open;
  final VoidCallback onToggle, onEdit, onDelete;
  const TaskCard({super.key, required this.task, required this.store, required this.open, required this.onToggle, required this.onEdit, required this.onDelete});
  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with SingleTickerProviderStateMixin {
  late final AnimationController out = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool completing = false;
  Task get t => widget.task;
  AppStore get store => widget.store;

  @override
  void dispose() {
    out.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (completing) return;
    setState(() => completing = true);
    if (store.haptics) HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 260));
    await out.forward();
    store.complete(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final cat = store.catOf(t);
    final color = cat != null ? Color(cat.color) : Colors.white.withValues(alpha: .3);
    final running = t.runningSince != null;
    final sDone = t.subs.where((s) => s.done).length;

    final card = AnimatedBuilder(
      animation: out,
      builder: (_, child) {
        final v = Curves.easeInCubic.transform(out.value);
        return Opacity(
          opacity: 1 - v,
          child: Transform.translate(offset: Offset(0, -30 * v), child: Transform.scale(scale: 1 - .1 * v, child: child)),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: C.glass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: completing ? C.ok.withValues(alpha: .5) : C.line),
          boxShadow: completing ? [BoxShadow(color: C.ok.withValues(alpha: .35), blurRadius: 40)] : const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Column(children: [
          Stack(children: [
            Positioned(
              left: 0,
              top: 16,
              bottom: 16,
              child: Container(
                width: 3,
                decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)), boxShadow: [BoxShadow(color: color, blurRadius: 12)]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(children: [
                _CheckButton(done: completing, onTap: _complete),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onToggle,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.title,
                          style: sora(17, w: FontWeight.w500, height: 1.3, color: completing ? C.muted : C.text)
                              .copyWith(decoration: completing ? TextDecoration.lineThrough : null)),
                      const SizedBox(height: 7),
                      Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        if (cat != null) _Tag(cat.name, color),
                        _Meta(sizeNames[t.size]),
                        if (t.due != null) _DueChip(t),
                        if (t.subs.isNotEmpty) _Meta('$sDone/${t.subs.length} pasos'),
                        if (t.repeat != Repeat.none) _Meta('↻ ${repeatNames[t.repeat]}'),
                        if (running || t.activeMs > 0) Every(builder: (_) => _Meta(fmtClock(t.focusMs), live: running)),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundIcon(
                  icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  tint: running ? C.warn : null,
                  label: running ? 'Pausar cronómetro' : 'Empezar cronómetro',
                  onTap: () {
                    if (store.haptics) HapticFeedback.lightImpact();
                    running ? store.pause(t.id) : store.start(t.id);
                  },
                ),
              ]),
            ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: widget.open ? _Detail(task: t, store: store, onEdit: widget.onEdit, onDelete: widget.onDelete) : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );

    return Dismissible(
      key: ValueKey('d-${t.id}'),
      background: _SwipeBg(left: true),
      secondaryBackground: _SwipeBg(left: false),
      dismissThresholds: const {DismissDirection.startToEnd: .35, DismissDirection.endToStart: .35},
      onDismissed: (d) {
        if (d == DismissDirection.startToEnd) {
          store.complete(t.id);
        } else {
          widget.onDelete();
        }
      },
      child: card,
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final bool left;
  const _SwipeBg({required this.left});
  @override
  Widget build(BuildContext context) {
    final c = left ? C.ok : C.hot;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: left ? Alignment.centerLeft : Alignment.centerRight,
          end: left ? Alignment.centerRight : Alignment.centerLeft,
          colors: [c.withValues(alpha: .35), c.withValues(alpha: 0)],
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(left ? Icons.check_rounded : Icons.delete_outline_rounded, color: c),
        const SizedBox(width: 6),
        Text(left ? 'Hecha' : 'Borrar', style: sora(14, w: FontWeight.w600, color: c)),
      ]),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  const _CheckButton({required this.done, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Marcar como hecha',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? C.ok : Colors.white.withValues(alpha: .04),
              border: Border.all(color: done ? C.ok : C.line2, width: 1.5),
              boxShadow: done ? [BoxShadow(color: C.ok.withValues(alpha: .8), blurRadius: 22)] : null,
            ),
            child: AnimatedScale(
              scale: done ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: const Icon(Icons.check_rounded, color: C.ink, size: 26),
            ),
          ),
        ),
      );
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final Color? tint;
  final String label;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, this.tint, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint?.withValues(alpha: .16) ?? C.glass2,
              border: Border.all(color: tint?.withValues(alpha: .5) ?? C.line),
            ),
            child: Icon(icon, size: 20, color: tint ?? C.text),
          ),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .45))),
        child: Text(text, style: sora(12, w: FontWeight.w500)),
      );
}

class _Meta extends StatelessWidget {
  final String text;
  final bool live;
  final Color? tint;
  const _Meta(this.text, {this.live = false, this.tint});
  @override
  Widget build(BuildContext context) {
    final c = tint ?? (live ? C.sky : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c?.withValues(alpha: .14) ?? C.glass2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c?.withValues(alpha: .55) ?? C.line),
        boxShadow: live ? [BoxShadow(color: C.sky.withValues(alpha: .35), blurRadius: 10)] : null,
      ),
      child: Text(text, style: mono(11, w: FontWeight.w500, color: c != null ? Color.lerp(c, Colors.white, .5)! : C.muted)),
    );
  }
}

class _DueChip extends StatelessWidget {
  final Task t;
  const _DueChip(this.t);
  @override
  Widget build(BuildContext context) {
    final d = t.due! - nowMs();
    if (d < 0) return const _Meta('Vencida · ×2', tint: C.hot);
    final label = d < 3600000
        ? 'Vence en ${(d / 60000).ceil()} min'
        : dayKey(t.due!) == dayKey(nowMs())
            ? 'Hoy ${fmtTime(t.due!)}'
            : 'Vence ${fmtDate(t.due!)}';
    return _Meta(label, tint: d < 86400000 ? C.warn : null);
  }
}

class _Detail extends StatefulWidget {
  final Task task;
  final AppStore store;
  final VoidCallback onEdit, onDelete;
  const _Detail({required this.task, required this.store, required this.onEdit, required this.onDelete});
  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  late final notes = TextEditingController(text: widget.task.notes);
  final sub = TextEditingController();
  final subFocus = FocusNode();
  Timer? _debounce;
  Task get t => widget.task;
  AppStore get store => widget.store;

  @override
  void dispose() {
    _debounce?.cancel();
    store.setNotes(t.id, notes.text);
    notes.dispose();
    sub.dispose();
    subFocus.dispose();
    super.dispose();
  }

  static const _ev = {'created': 'Creada', 'started': 'Empezaste', 'paused': 'Pausaste', 'done': 'Completada', 'reopened': 'Reabierta', 'edited': 'Editada', 'sub': 'Paso hecho'};
  static const _evColor = {'done': C.ok, 'started': C.sky, 'paused': C.warn, 'reopened': C.hot, 'sub': C.violet, 'edited': Color(0xFFFFD58A)};

  @override
  Widget build(BuildContext context) {
    final running = t.runningSince != null;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _Kv('Tiempo enfocado', running || t.activeMs > 0 ? null : '—', live: running || t.activeMs > 0 ? t : null)),
          const SizedBox(width: 8),
          Expanded(child: _Kv('Desde que la anotaste', fmtDur(nowMs() - t.createdAt))),
        ]),
        if (t.due != null) ...[
          const SizedBox(height: 8),
          _Kv('Fecha límite', fmtWhen(t.due!)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            Pill('Agregar a Calendario', small: true, color: C.sky, icon: Icons.event_rounded, onTap: () => Reminders.instance.addToCalendar(t)),
            if (t.remind) Padding(padding: const EdgeInsets.only(top: 8), child: Text(kIsWeb ? 'Agrégala al Calendario y el iPhone te avisa 1 día, 3 h, 1 h y 30 min antes.' : 'Te aviso 1 día, 3 h, 1 h y 30 min antes.', style: sora(12, color: C.faint))),
          ]),
        ],
        const SizedBox(height: 16),
        Text('PASOS', style: label()),
        const SizedBox(height: 8),
        for (final s in t.subs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              GestureDetector(
                onTap: () {
                  if (store.haptics) HapticFeedback.lightImpact();
                  if (!s.done) SoundEngine.instance.play('tick', volume: .7);
                  store.toggleSub(t.id, s.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.done ? C.ok : Colors.transparent,
                    border: Border.all(color: s.done ? C.ok : C.line2, width: 1.5),
                    boxShadow: s.done ? [BoxShadow(color: C.ok.withValues(alpha: .7), blurRadius: 12)] : null,
                  ),
                  child: s.done ? const Icon(Icons.check_rounded, size: 16, color: C.ink) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.text,
                    style: sora(15, color: s.done ? C.faint : C.text).copyWith(decoration: s.done ? TextDecoration.lineThrough : null, decorationColor: C.faint)),
              ),
              GestureDetector(onTap: () => store.removeSub(t.id, s.id), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close_rounded, size: 18, color: C.faint))),
            ]),
          ),
        Row(children: [
          Expanded(
            child: _Field(
              controller: sub,
              focus: subFocus,
              hint: 'Agregar un paso',
              onSubmit: (v) {
                if (v.trim().isEmpty) return;
                store.addSub(t.id, v.trim());
                sub.clear();
                subFocus.requestFocus();
              },
            ),
          ),
          const SizedBox(width: 8),
          Pill('+', small: true, primary: true, onTap: () {
            if (sub.text.trim().isEmpty) return;
            store.addSub(t.id, sub.text.trim());
            sub.clear();
          }),
        ]),
        if (t.subs.isEmpty) ...[
          const SizedBox(height: 8),
          Text('Partir algo grande en pasos chicos baja la carga poco a poco.', style: sora(13, color: C.faint)),
        ],
        const SizedBox(height: 16),
        Text('NOTAS', style: label()),
        const SizedBox(height: 8),
        _Field(
          controller: notes,
          hint: 'Números, links, lo que necesites recordar',
          lines: 3,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 600), () => store.setNotes(t.id, v));
          },
        ),
        const SizedBox(height: 16),
        Text('TRAZA', style: label()),
        const SizedBox(height: 8),
        for (var i = 0; i < t.log.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 14,
                child: Column(children: [
                  const SizedBox(height: 9),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _evColor[t.log[i].e] ?? C.faint, boxShadow: [BoxShadow(color: (_evColor[t.log[i].e] ?? C.faint).withValues(alpha: .6), blurRadius: 8)]),
                  ),
                  if (i < t.log.length - 1) Expanded(child: Container(width: 1, color: C.line2)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text('${_ev[t.log[i].e] ?? t.log[i].e}${t.log[i].x != null ? ': ${t.log[i].x}' : ''}', style: sora(14)),
                ),
              ),
              Padding(padding: const EdgeInsets.only(top: 7), child: Text(fmtWhen(t.log[i].t), style: mono(11, color: C.faint))),
            ]),
          ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, children: [
          Pill('Editar', small: true, onTap: widget.onEdit),
          Pill('Borrar', small: true, color: C.hot, onTap: widget.onDelete),
        ]),
      ]),
    );
  }
}

class _Kv extends StatelessWidget {
  final String k;
  final String? v;
  final Task? live;
  const _Kv(this.k, this.v, {this.live});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.toUpperCase(), style: sora(10.5, w: FontWeight.w500, color: C.muted, ls: .8)),
          const SizedBox(height: 4),
          live != null ? Every(builder: (_) => Text(fmtClock(live!.focusMs), style: mono(16, w: FontWeight.w500))) : Text(v ?? '', style: mono(16, w: FontWeight.w500)),
        ]),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int lines;
  final FocusNode? focus;
  final ValueChanged<String>? onSubmit, onChanged;
  const _Field({super.key, required this.controller, required this.hint, this.lines = 1, this.focus, this.onSubmit, this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focus,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 6,
        onSubmitted: onSubmit,
        onChanged: onChanged,
        textInputAction: lines == 1 ? TextInputAction.done : TextInputAction.newline,
        style: sora(16),
        cursorColor: Theme.of(context).colorScheme.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: sora(16, color: C.faint),
          filled: true,
          fillColor: Colors.white.withValues(alpha: .06),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: .6))),
        ),
      );
}

/// Exposed for the sheet.
class GlassField extends _Field {
  const GlassField({super.key, required super.controller, required super.hint, super.lines, super.focus, super.onSubmit, super.onChanged});
}
