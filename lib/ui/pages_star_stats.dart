import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../star/solar_system.dart';
import '../store.dart';
import 'pages_tasks.dart';
import 'theme.dart';

const _bottomPad = 170.0;
const _kindName = {PlanetKind.rocky: 'Rocoso', PlanetKind.gas: 'Gigante gaseoso', PlanetKind.ice: 'Helado'};

class StarPage extends StatelessWidget {
  final AppStore store;
  final ValueNotifier<(String, bool)?> stamp;
  const StarPage({super.key, required this.store, required this.stamp});

  @override
  Widget build(BuildContext context) {
    final load = store.load;
    final nebula = store.star.phase == Phase.nebula;
    final cur = store.level;
    final color = Color(cur.color);
    final solar = SolarScene.of(store);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomPad),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: C.line),
              gradient: const RadialGradient(colors: [Color(0x0AFFFFFF), Color(0x03FFFFFF)]),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              Positioned.fill(child: SolarSystem(store: store)),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .4), borderRadius: BorderRadius.circular(99), border: Border.all(color: C.line)),
                  child: Row(children: [
                    const _RecDot(),
                    const SizedBox(width: 7),
                    Text('EN VIVO', style: mono(11, w: FontWeight.w500, color: C.muted)),
                  ]),
                ),
              ),
              Positioned(
                left: 18,
                bottom: 16,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nebula ? 'Nebulosa' : cur.name, style: sora(30, w: FontWeight.w600, color: color, ls: -.6).copyWith(shadows: [Shadow(color: color.withValues(alpha: .6), blurRadius: 24)])),
                  Text(nebula ? 'Nace una estrella · ${store.star.progress}/$rebirthNeed' : 'Carga ${(load * 100).round()}% · límite 100%', style: mono(12, color: C.muted)),
                ]),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<(String, bool)?>(
                    valueListenable: stamp,
                    builder: (_, v, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: FadeTransition(opacity: a, child: c)),
                      child: v == null
                          ? const SizedBox.shrink()
                          : Center(
                              key: ValueKey(v.$1),
                              child: Glass(
                                blur: true,
                                radius: 99,
                                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                                child: Text(v.$1,
                                    style: sora(30, w: FontWeight.w600, color: v.$2 ? const Color(0xFFD6F0FF) : const Color(0xFFFFD0E8))
                                        .copyWith(shadows: [Shadow(color: v.$2 ? C.sky : const Color(0xFFFF6BD5), blurRadius: 24)])),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (nebula) ...[HopeBanner(store: store), const SizedBox(height: 14)],
        Text('Mi estrella', style: sora(28, w: FontWeight.w600, ls: -.5)),
        const SizedBox(height: 6),
        Text('Cada tarea pendiente le suma carga. Las vencidas pesan el doble. Si pasa de 100% explota, y de la nebulosa nace una nueva en cuanto terminas $rebirthNeed tareas.',
            style: sora(14, color: C.faint, height: 1.45)),
        const SizedBox(height: 14),
        Glass(
          padding: const EdgeInsets.all(6),
          child: Column(children: [
            for (var i = 0; i < starLevels.length; i++) _Rung(level: starLevels[i], lo: i == 0 ? 0 : starLevels[i - 1].max, now: starLevels[i] == cur, last: i == starLevels.length - 1),
          ]),
        ),
        const SizedBox(height: 14),
        Glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TU SISTEMA SOLAR', style: label()),
            const SizedBox(height: 12),
            if (solar.planets.isEmpty)
              Text('Crea tipos de tareas y aparecerán como planetas girando alrededor de tu estrella.', style: sora(13, color: C.faint))
            else
              for (final p in solar.planets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Orb(color: p.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: sora(15, w: FontWeight.w500)),
                        Text(
                          '${_kindName[p.kind]}${p.ring ? ' con anillos' : ''} · ${p.moons == 0 ? 'sin lunas' : p.moons == 1 ? '1 luna' : '${p.moons} lunas'} · ${dueLabel(p.nextDue)}',
                          style: sora(12, color: p.urgency > .6 ? C.warn : C.faint),
                        ),
                      ]),
                    ),
                    Text('${store.pctOf(p.load)}%', style: mono(12, color: C.muted)),
                  ]),
                ),
            const SizedBox(height: 4),
            Text(
              'Cada tipo de tarea es un planeta: crece con su carga y su órbita se acerca a la estrella cuando se acerca la fecha límite. '
              'Cada subtarea pendiente es una luna. Cada tarea que terminas queda como una roca en el cinturón de asteroides '
              '(${solar.belt.length}${solar.belt.length >= maxRocks ? '+' : ''}). Si la estrella explota, los planetas salen disparados.',
              style: sora(13, color: C.faint, height: 1.45),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _Tiles([
          ('${store.star.rebirths}', 'renacimientos', C.ok),
          ('${store.star.supernovas}', 'supernovas', const Color(0xFFD7A8FF)),
          ('${(load * 100).round()}%', 'carga ahora', color),
        ]),
      ],
    );
  }
}

class _RecDot extends StatefulWidget {
  const _RecDot();
  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .3, end: 1.0).animate(c),
        child: Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: C.hot, boxShadow: [BoxShadow(color: C.hot, blurRadius: 8)])),
      );
}

class _Rung extends StatelessWidget {
  final StarLevel level;
  final double lo;
  final bool now, last;
  const _Rung({required this.level, required this.lo, required this.now, required this.last});
  @override
  Widget build(BuildContext context) {
    final color = Color(level.color);
    final range = last ? '> 100%' : '${(lo * 100).round()}–${(level.max * 100).round()}%';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: now ? Colors.white.withValues(alpha: .08) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: now ? color.withValues(alpha: .45) : Colors.transparent),
      ),
      child: Row(children: [
        Orb(color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(level.name, style: sora(15, w: FontWeight.w600, color: now ? color : C.text)),
            const SizedBox(height: 2),
            Text(level.hint, style: sora(13, color: C.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        now
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
                child: Text('Ahora', style: mono(11, w: FontWeight.w500, color: C.ink)),
              )
            : Text(range, style: mono(11, color: C.faint)),
      ]),
    );
  }
}

class _Tiles extends StatelessWidget {
  final List<(String, String, Color)> items;
  const _Tiles(this.items);
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Glass(
              radius: 16,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  child: Text(items[i].$1, style: mono(26, w: FontWeight.w500, color: items[i].$3).copyWith(shadows: [Shadow(color: items[i].$3.withValues(alpha: .5), blurRadius: 18)])),
                ),
                const SizedBox(height: 6),
                Text(items[i].$2.toUpperCase(), style: sora(10.5, w: FontWeight.w500, color: C.muted, ls: .6)),
              ]),
            ),
          ),
        ],
      ]);
}

/* ============================== progress ============================== */

class StatsPage extends StatelessWidget {
  final AppStore store;
  final VoidCallback onGoTasks;
  const StatsPage({super.key, required this.store, required this.onGoTasks});

  @override
  Widget build(BuildContext context) {
    final done = store.done;
    if (done.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomPad), children: [
        Text('Tu progreso', style: sora(28, w: FontWeight.w600, ls: -.5)),
        const SizedBox(height: 14),
        Glass(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Aquí verás todo lo que soltaste.', style: sora(21, w: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('Cuánta carga le quitaste a tu estrella, cuánto tardaste en cada cosa, tu racha de días y la historia completa. Completa tu primera tarea para empezar.',
                style: sora(15, color: C.muted, height: 1.45)),
            const SizedBox(height: 16),
            Pill('Ir a mis tareas', primary: true, onTap: onGoTasks),
          ]),
        ),
      ]);
    }
    final freed = store.pctOf(done.fold<double>(0, (a, t) => a + t.size));
    final days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    final perDay = days.map((d) => done.where((t) => dayKey(t.completedAt!) == dayKey(d.millisecondsSinceEpoch)).length).toList();
    final maxDay = max(1, perDay.reduce(max));
    final times = done.map((t) => t.takenMs).toList();
    final avg = times.reduce((a, b) => a + b) ~/ times.length;
    final fastest = done.reduce((a, b) => b.takenMs < a.takenMs ? b : a);
    final biggest = done.reduce((a, b) => b.size > a.size ? b : a);
    const wd = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    final catRows = <Widget>[];
    for (final (id, name, color) in [...store.sortedCats.map((c) => (c.id, c.name, Color(c.color))), (null, 'Sin tipo', Colors.white)]) {
      final ts = store.tasks.values.where((t) => (id == null ? store.catOf(t) == null : t.catId == id) && (t.completedAt != null || t.isVisible)).toList();
      if (ts.isEmpty) continue;
      final d = ts.where((t) => t.completedAt != null).length;
      catRows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(name, style: sora(15))), Text('$d/${ts.length}', style: mono(12, color: C.muted))]),
          const SizedBox(height: 6),
          _Bar(frac: d / ts.length, color: color),
        ]),
      ));
    }

    final hist = <Widget>[];
    String last = '';
    for (final t in done.take(80)) {
      final k = dayKey(t.completedAt!);
      if (k != last) {
        hist.add(Padding(padding: const EdgeInsets.fromLTRB(2, 10, 0, 6), child: Text(fmtDay(t.completedAt!).toUpperCase(), style: mono(11, w: FontWeight.w500, color: C.muted))));
        last = k;
      }
      final cat = store.catOf(t);
      hist.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Orb(color: cat != null ? Color(cat.color) : Colors.white, size: 8),
            const SizedBox(width: 10),
            Expanded(child: Text(t.title, style: sora(15, w: FontWeight.w500))),
            Text(fmtDur(t.takenMs), style: mono(12, color: C.ok)),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(
              '${cat?.name ?? 'Sin tipo'} · ${sizeNames[t.size]}${t.subs.isNotEmpty ? ' · ${t.subs.length} pasos' : ''} · anotada ${fmtWhen(t.createdAt)} · hecha ${fmtWhen(t.completedAt!)}${t.due != null ? (t.completedAt! <= t.due! ? ' · a tiempo' : ' · después del límite') : ''}',
              style: mono(11, color: C.faint),
            ),
          ),
        ]),
      ));
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, _bottomPad), children: [
      Text('Tu progreso', style: sora(28, w: FontWeight.w600, ls: -.5)),
      const SizedBox(height: 14),
      _Tiles([('${done.length}', 'tareas hechas', C.ok), ('$freed%', 'carga soltada', Theme.of(context).colorScheme.primary), ('${store.streak}', store.streak == 1 ? 'día de racha' : 'días de racha', C.sky)]),
      const SizedBox(height: 14),
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TAREAS POR DÍA · ÚLTIMOS 7', style: label()),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(perDay[i] > 0 ? '${perDay[i]}' : '', style: mono(11, w: FontWeight.w500)),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: perDay[i] / maxDay),
                      duration: Duration(milliseconds: 700 + i * 60),
                      curve: Curves.easeOutBack,
                      builder: (_, v, _) => Container(
                        width: 22,
                        height: max(4, 100 * v),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: i == 6 ? [C.ok, C.sky] : [C.sky, C.violet]),
                          boxShadow: [BoxShadow(color: (i == 6 ? C.ok : C.sky).withValues(alpha: .4), blurRadius: 14)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(wd[days[i].weekday - 1], style: mono(11, color: C.faint)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TIEMPOS', style: label()),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Mini('Promedio', fmtDur(avg))),
            const SizedBox(width: 8),
            Expanded(child: _Mini('Más rápida', fmtDur(fastest.takenMs))),
          ]),
          const SizedBox(height: 8),
          _Mini('Lo más grande que soltaste', '${biggest.title} · ${sizeNames[biggest.size]}'),
        ]),
      ),
      if (catRows.isNotEmpty) ...[
        const SizedBox(height: 14),
        Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('AVANCE POR TIPO', style: label()), const SizedBox(height: 12), ...catRows])),
      ],
      const SizedBox(height: 18),
      Text('HISTORIAL', style: label()),
      ...hist,
    ]);
  }
}

class _Mini extends StatelessWidget {
  final String k, v;
  const _Mini(this.k, this.v);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.toUpperCase(), style: sora(10.5, w: FontWeight.w500, color: C.muted, ls: .6)),
          const SizedBox(height: 4),
          Text(v, style: mono(15, w: FontWeight.w500)),
        ]),
      );
}

class _Bar extends StatelessWidget {
  final double frac;
  final Color color;
  const _Bar({required this.frac, required this.color});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(children: [
          Container(height: 8, color: Colors.white.withValues(alpha: .08)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99), boxShadow: [BoxShadow(color: color, blurRadius: 10)])),
            ),
          ),
        ]),
      );
}
