import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../store.dart';
import 'star_fx.dart';

/// Stable 0..1 hash of a string (String.hashCode is not guaranteed stable between runs).
double hash01(String s, [int salt = 0]) {
  var h = 0x811C9DC5 ^ salt;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  h ^= h >> 15;
  h = (h * 0x2C1B3C6D) & 0xFFFFFFFF;
  h ^= h >> 12;
  return (h & 0xFFFFFF) / 0x1000000;
}

enum PlanetKind { rocky, gas, ice }

/// One task type seen as a planet.
class PlanetInfo {
  final String id, name;
  final Color color;
  final double load;
  /// 0 = no deadline soon, 1 = due now or overdue. Pulls the orbit toward the star.
  final double urgency;
  /// Pending subtasks of this type's tasks (each one is a moon).
  final int moons;
  final int? nextDue;
  final PlanetKind kind;
  final bool ring;
  final double seed;
  const PlanetInfo({
    required this.id,
    required this.name,
    required this.color,
    required this.load,
    required this.urgency,
    required this.moons,
    required this.nextDue,
    required this.kind,
    required this.ring,
    required this.seed,
  });
}

/// One finished task left behind as a rock in the asteroid belt.
class Rock {
  final Color color;
  final double size, r, a0, y, speed;
  final bool fresh;
  const Rock(this.color, this.size, this.r, this.a0, this.y, this.speed, this.fresh);
}

const maxMoons = 6;
const maxRocks = 260;
const noTypeId = '_none';
const noTypeColor = 0xFFB9BDD6;

class SolarScene {
  final List<PlanetInfo> planets;
  final List<Rock> belt;
  const SolarScene(this.planets, this.belt);

  static PlanetInfo _planet(String id, String name, Color color, Iterable<Task> tasks) {
    final pend = tasks.where((t) => t.isVisible).toList();
    final load = pend.fold<double>(0, (a, t) => a + t.load);
    final moons = pend.fold<int>(0, (a, t) => a + t.subs.where((s) => !s.done).length);
    int? due;
    for (final t in pend) {
      if (t.due != null && (due == null || t.due! < due)) due = t.due;
    }
    var urgency = 0.0;
    if (due != null) {
      final h = (due - nowMs()) / 3600000;
      urgency = h <= 0 ? 1 : (1 - h / (7 * 24)).clamp(0.0, 1.0);
      urgency = urgency * urgency * (3 - 2 * urgency);
    }
    final k = hash01(id, 7);
    final kind = k < .45 ? PlanetKind.rocky : (k < .75 ? PlanetKind.gas : PlanetKind.ice);
    return PlanetInfo(
      id: id,
      name: name,
      color: color,
      load: load,
      urgency: urgency,
      moons: min(moons, maxMoons),
      nextDue: due,
      kind: kind,
      ring: kind == PlanetKind.gas ? hash01(id, 3) < .6 : hash01(id, 3) < .12,
      seed: hash01(id, 11),
    );
  }

  factory SolarScene.of(AppStore s) {
    final planets = <PlanetInfo>[
      for (final c in s.sortedCats) _planet(c.id, c.name, Color(c.color), s.tasks.values.where((t) => t.catId == c.id)),
    ];
    final loose = s.tasks.values.where((t) => t.catId == null || !s.cats.containsKey(t.catId));
    if (loose.any((t) => t.isVisible)) planets.add(_planet(noTypeId, 'Sin tipo', const Color(noTypeColor), loose));

    final done = s.done.take(maxRocks);
    final day = nowMs() - 86400000;
    final belt = <Rock>[
      for (final t in done)
        Rock(
          Color.lerp(s.catOf(t) != null ? Color(s.catOf(t)!.color) : const Color(noTypeColor), const Color(0xFF9A93A0), .45)!,
          .7 + t.size * .28,
          hash01(t.id, 1),
          hash01(t.id, 2) * pi * 2,
          (hash01(t.id, 4) - .5),
          .8 + hash01(t.id, 5) * .4,
          t.completedAt! > day,
        ),
    ];
    return SolarScene(planets, belt);
  }
}

/// Animated, smoothed state of a planet between frames.
class _Body {
  double angle, spin, slot, urgency, grow = 0;
  _Body(this.angle, this.slot, this.urgency) : spin = angle;
}

/// The observatory: planets and belt behind the star, the star shader, then everything in front.
class SolarSystem extends StatefulWidget {
  final AppStore store;
  const SolarSystem({super.key, required this.store});
  @override
  State<SolarSystem> createState() => _SolarSystemState();
}

class _SolarSystemState extends State<SolarSystem> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  final bodies = <String, _Body>{};
  final _shaders = <ui.FragmentShader>[];
  SolarScene scene = const SolarScene([], []);
  double t = 0, beltAngle = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  ui.FragmentShader? shader(int i) {
    final prog = StarFx.planetProgram;
    if (prog == null) return null;
    while (_shaders.length <= i) {
      _shaders.add(prog.fragmentShader());
    }
    return _shaders[i];
  }

  void _tick(Duration e) {
    final dt = _last == Duration.zero ? .016 : ((e - _last).inMicroseconds / 1e6).clamp(0.0, .1);
    _last = e;
    final slow = StarFx.instance.reduced ? .3 : 1.0;
    t += dt * slow;
    beltAngle += dt * slow * .05;
    final n = scene.planets.length;
    for (var i = 0; i < n; i++) {
      final p = scene.planets[i];
      final slotT = n == 1 ? .5 : i / (n - 1);
      final b = bodies.putIfAbsent(p.id, () => _Body(p.seed * pi * 2, slotT, p.urgency));
      final k = 1 - exp(-dt * 1.5);
      b.slot += (slotT - b.slot) * k;
      b.urgency += (p.urgency - b.urgency) * k;
      b.grow += (1 - b.grow) * (1 - exp(-dt * 2.2));
      // Kepler: inner orbits run faster (period ~ r^1.5)
      final rel = .45 + .55 * b.slot * (1 - .3 * b.urgency);
      b.angle += dt * slow * .32 / pow(rel / .5, 1.5);
      b.spin += dt * slow * (.35 + p.seed * .3);
    }
    bodies.removeWhere((id, _) => !scene.planets.any((p) => p.id == id));
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    scene = SolarScene.of(widget.store);
    return Stack(children: [
      Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _SolarPainter(this, false)))),
      const Positioned.fill(child: StarView(detail: 1)),
      Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _SolarPainter(this, true)))),
    ]);
  }
}

/// Fixed camera: orbits lie in a plane seen from a little above, rolled slightly.
const _elev = .33, _roll = -.18;

class _Proj {
  final Offset p;
  final double z, scale;
  final List<double> light; // direction toward the star, view space (x right, y up, z to viewer)
  _Proj(this.p, this.z, this.scale, this.light);
}

class _Item {
  final double z;
  final void Function() draw;
  _Item(this.z, this.draw);
}

class _SolarPainter extends CustomPainter {
  final _SolarSystemState s;
  final bool front;
  _SolarPainter(this.s, this.front) : super(repaint: s._repaint);

  _Proj _project(Offset c, double x, double y, double z, double ref) {
    final vy = y * cos(_elev) - z * sin(_elev);
    final vz = y * sin(_elev) + z * cos(_elev);
    final rx = x * cos(_roll) - vy * sin(_roll);
    final ry = x * sin(_roll) + vy * cos(_roll);
    final d = sqrt(rx * rx + ry * ry + vz * vz);
    final l = d < 1e-6 ? [0.0, 0.0, 1.0] : [-rx / d, -ry / d, -vz / d];
    return _Proj(Offset(c.dx + rx, c.dy - ry), vz, 1 + .12 * vz / ref, l);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fx = StarFx.instance;
    final scene = s.scene;
    final sz = min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final starR = .16 * (.8 + .55 * min(fx.smoothLoad, 1.1)) * sz;
    final inner = starR * 1.95, outer = sz * .38;
    final light = StarFx.lightColor(fx.smoothLoad);

    // Supernova blows everything outward; rebirth condenses it back out of the nebula.
    var spread = 1.0, vis = 1.0;
    switch (fx.mode) {
      case StarMode.exploding:
        final k = fx.phaseK;
        spread = 1 + 5 * k * k;
        vis = 1 - Curves.easeIn.transform(k);
      case StarMode.nebula:
        vis = 0;
      case StarMode.reborn:
        final k = ((fx.phaseK - .4) / .6).clamp(0.0, 1.0);
        vis = Curves.easeOut.transform(k);
        spread = 1 + (1 - vis) * .5;
      case StarMode.star:
        break;
    }
    if (vis <= .001) return;

    final items = <_Item>[];

    // orbit guides (always behind)
    if (!front) {
      for (final p in scene.planets) {
        final b = s.bodies[p.id];
        if (b == null) continue;
        final r = _orbitR(b, inner, outer, starR) * spread;
        final path = Path();
        for (var i = 0; i <= 72; i++) {
          final a = i / 72 * pi * 2;
          final q = _project(c, cos(a) * r, 0, sin(a) * r, outer).p;
          i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Color.lerp(Colors.white, p.color, .35 + .5 * b.urgency)!.withValues(alpha: (.07 + .12 * b.urgency) * vis));
      }
    }

    // asteroid belt: one rock per finished task
    final beltIn = outer * 1.1, beltOut = sz * .47;
    final rockPaint = Paint();
    for (final k in scene.belt) {
      final r = (beltIn + (beltOut - beltIn) * k.r) * spread;
      final a = k.a0 + s.beltAngle * k.speed * pow(beltIn / r, 1.5);
      final pr = _project(c, cos(a) * r, k.y * sz * .018, sin(a) * r, outer);
      if ((pr.z > 0) != front) continue;
      final rad = k.size * pr.scale * (k.fresh ? 1.25 : 1);
      if (k.fresh) {
        rockPaint.color = k.color.withValues(alpha: .13 * vis);
        canvas.drawCircle(pr.p, rad * 2, rockPaint);
      }
      rockPaint.color = Color.lerp(k.color, Colors.white, k.fresh ? .45 : 0)!.withValues(alpha: (k.fresh ? .95 : .55) * vis);
      canvas.drawCircle(pr.p, rad, rockPaint);
    }

    // planets and moons, sorted back to front
    // each planet owns one shader instance (it is drawn in only one of the two layers per frame)
    for (var pi_ = 0; pi_ < scene.planets.length; pi_++) {
      final p = scene.planets[pi_];
      final b = s.bodies[p.id];
      if (b == null) continue;
      final r = _orbitR(b, inner, outer, starR) * spread;
      final x = cos(b.angle) * r, z = sin(b.angle) * r;
      final pr = _project(c, x, 0, z, outer);
      final rad = (sz * .016 + sqrt(p.load) * sz * .011).clamp(sz * .014, sz * .05) * pr.scale * b.grow;
      final alpha = vis * b.grow;
      if ((pr.z > 0) == front) {
        items.add(_Item(pr.z, () => _drawPlanet(canvas, p, b, pr, rad, light, alpha, pi_)));
      }
      for (var j = 0; j < p.moons; j++) {
        final mr = rad / max(pr.scale, .01) * (2.0 + j * .55);
        final ma = s.t * (1.4 / (1 + j * .45)) + j * 2.4 + p.seed * 6;
        final mp = _project(c, x + cos(ma) * mr, sin(ma) * mr * .18, z + sin(ma) * mr, outer);
        if ((mp.z > 0) != front) continue;
        final mrad = max(1.4, rad * (.2 + .04 * ((j * 7) % 3)));
        items.add(_Item(mp.z, () => _drawMoon(canvas, p.color, mp, mrad, alpha)));
      }
    }
    items.sort((a, b) => a.z.compareTo(b.z));
    for (final it in items) {
      it.draw();
    }
  }

  double _orbitR(_Body b, double inner, double outer, double starR) {
    final base = inner + (outer - inner) * b.slot;
    return max(starR * 1.55, base * (1 - .3 * b.urgency));
  }

  void _drawPlanet(Canvas canvas, PlanetInfo p, _Body b, _Proj pr, double rad, List<double> light, double alpha, int ix) {
    if (rad < .5) return;
    final sh = s.shader(ix);
    if (sh == null) {
      // fallback without shader support: shaded disc lit from the star's side
      canvas.drawCircle(
        pr.p,
        rad,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(pr.light[0] * .5, -pr.light[1] * .5),
            colors: [Color.lerp(p.color, Colors.white, .5)!, p.color, Color.lerp(p.color, Colors.black, .85)!],
            stops: const [0, .55, 1],
          ).createShader(Rect.fromCircle(center: pr.p, radius: rad)),
      );
      return;
    }
    var i = 0;
    sh.setFloat(i++, pr.p.dx);
    sh.setFloat(i++, pr.p.dy);
    sh.setFloat(i++, rad);
    for (final v in pr.light) {
      sh.setFloat(i++, v);
    }
    sh.setFloat(i++, p.color.r);
    sh.setFloat(i++, p.color.g);
    sh.setFloat(i++, p.color.b);
    for (final v in light) {
      sh.setFloat(i++, v);
    }
    sh.setFloat(i++, p.kind.index.toDouble());
    sh.setFloat(i++, p.seed);
    sh.setFloat(i++, b.spin);
    sh.setFloat(i++, p.ring ? 1 : 0);
    sh.setFloat(i++, alpha);
    sh.setFloat(i++, s.t);
    canvas.drawRect(Rect.fromCircle(center: pr.p, radius: rad * (p.ring ? 2.4 : 1.5)), Paint()..shader = sh);
  }

  void _drawMoon(Canvas canvas, Color tint, _Proj pr, double rad, double alpha) {
    final base = Color.lerp(const Color(0xFFB8B4AE), tint, .2)!;
    canvas.drawCircle(
      pr.p,
      rad,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(pr.light[0] * .6, -pr.light[1] * .6),
          radius: .9,
          colors: [Color.lerp(base, Colors.white, .5)!.withValues(alpha: alpha), base.withValues(alpha: alpha), Color.lerp(base, Colors.black, .9)!.withValues(alpha: alpha)],
          stops: const [0, .45, 1],
        ).createShader(Rect.fromCircle(center: pr.p, radius: rad)),
    );
  }

  @override
  bool shouldRepaint(covariant _SolarPainter old) => true;
}

/// Short Spanish description of when the nearest deadline of a planet is.
String dueLabel(int? due) {
  if (due == null) return 'sin fecha';
  final ms = due - nowMs();
  if (ms <= 0) return 'vencida';
  return 'vence en ${fmtDur(ms)}';
}
