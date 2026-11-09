import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../star/star_fx.dart';

class C {
  static const bg = Color(0xFF04050D);
  static const text = Color(0xFFEEF0FF);
  static const muted = Color(0xFFA3A8CC);
  static const faint = Color(0xFF6F75A0);
  static const ink = Color(0xFF0A0B18);
  static const glass = Color(0x0FFFFFFF);
  static const glass2 = Color(0x1AFFFFFF);
  static const line = Color(0x1FFFFFFF);
  static const line2 = Color(0x3DFFFFFF);
  static const ok = Color(0xFF7CF0B5);
  static const warn = Color(0xFFFFC86B);
  static const hot = Color(0xFFFF7A6B);
  static const violet = Color(0xFFB79CFF);
  static const sky = Color(0xFF7CC8FF);
}

TextStyle sora(double size, {FontWeight w = FontWeight.w400, Color color = C.text, double? height, double ls = 0}) =>
    GoogleFonts.sora(fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: ls);

TextStyle mono(double size, {FontWeight w = FontWeight.w400, Color color = C.text}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: w, color: color, fontFeatures: const [FontFeature.tabularFigures()]);

TextStyle label() => sora(11.5, w: FontWeight.w600, color: C.muted, ls: 1.2);

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.dark(primary: Color(0xFFFFD58A), surface: C.bg),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

/// Frosted glass panel. [blur] only where it matters (header, nav, sheets) to keep scrolling smooth.
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool blur;
  final Color? tint;
  final Color? border;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24, this.blur = false, this.tint, this.border});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? (blur ? const Color(0x8C0E1024) : C.glass),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? C.line),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 32, offset: Offset(0, 12))],
      ),
      child: child,
    );
    if (!blur) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: box),
    );
  }
}

/// Pill button with spring press.
class Pill extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? color;
  final bool primary;
  final bool small;
  final IconData? icon;
  const Pill(this.text, {super.key, this.onTap, this.color, this.primary = false, this.small = false, this.icon});
  @override
  State<Pill> createState() => _PillState();
}

class _PillState extends State<Pill> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final accent = widget.color;
    final star = Theme.of(context).colorScheme.primary;
    final fg = widget.primary ? C.ink : (accent ?? C.text);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .94 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: widget.small ? 14 : 20, vertical: widget.small ? 9 : 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: widget.primary
                ? LinearGradient(colors: [star, Color.lerp(star, Colors.white, .55)!], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: widget.primary ? null : (accent != null ? accent.withValues(alpha: .14) : C.glass2),
            border: Border.all(color: widget.primary ? Colors.transparent : (accent?.withValues(alpha: .5) ?? C.line2)),
            boxShadow: widget.primary ? [BoxShadow(color: star.withValues(alpha: .45), blurRadius: 24)] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: widget.small ? 16 : 18, color: fg), const SizedBox(width: 6)],
            Text(widget.text, style: sora(widget.small ? 14 : 16, w: FontWeight.w600, color: fg)),
          ]),
        ),
      ),
    );
  }
}

class Chip2 extends StatelessWidget {
  final String text;
  final bool on;
  final Color? dot;
  final String? count;
  final VoidCallback onTap;
  const Chip2(this.text, {super.key, this.on = false, this.dot, this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white.withValues(alpha: .92) : C.glass2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? Colors.transparent : C.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[Orb(color: dot!, size: 10), const SizedBox(width: 7)],
          Text(text, style: sora(14, w: FontWeight.w500, color: on ? C.ink : C.text)),
          if (count != null) ...[const SizedBox(width: 6), Text(count!, style: mono(12, color: on ? C.ink : C.muted))],
        ]),
      ),
    );
  }
}

/// Glowing sphere (categories, planets, legend dots).
class Orb extends StatelessWidget {
  final Color color;
  final double size;
  const Orb({super.key, required this.color, this.size = 18});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-.35, -.35), colors: [Colors.white.withValues(alpha: .85), color, Color.lerp(color, Colors.black, .35)!], stops: const [0, .45, 1]),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .7), blurRadius: size * .7)],
        ),
      );
}

/// iOS-style switch tinted with the "ok" green.
class Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const Toggle({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: C.ok, activeThumbColor: Colors.white);
}

/// Live night sky behind the whole app, tinted by the star's current color.
class SkyBackground extends StatefulWidget {
  final Color tint;
  final bool nebula;
  const SkyBackground({super.key, required this.tint, required this.nebula});
  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

final _stars = List.generate(160, (i) {
  final r = Random(i * 7919);
  return (r.nextDouble(), r.nextDouble(), r.nextDouble() * 1.1 + .25, r.nextDouble() * 6.28, .4 + r.nextDouble() * 1.8);
});

class _SkyBackgroundState extends State<SkyBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    var frame = 0;
    _ticker = createTicker((e) {
      if (frame++ % 2 == 0) _t.value = e.inMicroseconds / 1e6;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: _SkyPainter(_t, widget.tint, widget.nebula), size: Size.infinite),
      );
}

class _SkyPainter extends CustomPainter {
  final ValueNotifier<double> t;
  final Color tint;
  final bool nebula;
  _SkyPainter(this.t, this.tint, this.nebula) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size s) {
    final time = t.value;
    canvas.drawRect(Offset.zero & s, Paint()..color = C.bg);
    final blobs = [
      (.18, .10, .75, .05, nebula ? const Color(0xFFC878FF) : tint, .20),
      (.92, .38, .60, .04, const Color(0xFF785AFF), .13),
      (.25, .88, .70, .035, const Color(0xFF28A0E6), .10),
      (.80, .95, .50, .06, const Color(0xFFFF5AB4), .07),
    ];
    final m = max(s.width, s.height);
    for (var i = 0; i < blobs.length; i++) {
      final (x, y, r, sp, c, a) = blobs[i];
      final center = Offset((x + sin(time * sp + i) * .05) * s.width, (y + cos(time * sp * .8 + i) * .04) * s.height);
      final rad = r * m;
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(colors: [c.withValues(alpha: a), c.withValues(alpha: a * .35), c.withValues(alpha: 0)], stops: const [0, .5, 1])
              .createShader(Rect.fromCircle(center: center, radius: rad)),
      );
    }
    final p = Paint();
    for (final (x, y, r, ph, sp) in _stars) {
      p.color = Colors.white.withValues(alpha: .25 + .5 * (sin(time * sp * .5 + ph)).abs());
      canvas.drawCircle(Offset(x * s.width, y * s.height), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.tint != tint || old.nebula != nebula;
}

/// Planets (task types) orbiting the observatory star, drawn on top of the shader.
class PlanetsPainter extends CustomPainter {
  final List<(Color, double)> planets; // color, load
  final double time;
  final double starR; // fraction of min side
  final bool front;
  PlanetsPainter(this.planets, this.time, this.starR, this.front);

  @override
  void paint(Canvas canvas, Size size) {
    if (planets.isEmpty) return;
    final sz = min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final R = starR * sz;
    final maxR = sz * .47;
    final step = min(R * .42, (maxR - R * 1.75) / max(1, planets.length));
    const tilt = -.18;
    for (var i = 0; i < planets.length; i++) {
      final (color, load) = planets[i];
      final rx = R * 1.75 + step * (i + .5), ry = rx * .32;
      if (!front) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(tilt);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white.withValues(alpha: .1));
        canvas.restore();
      }
      final a = i * 2.1 + time * (.28 / (1 + i * .35));
      final sa = sin(a);
      if ((sa >= 0) != front) continue;
      final ca = cos(a);
      final x = c.dx + ca * rx * cos(tilt) - sa * ry * sin(tilt);
      final y = c.dy + ca * rx * sin(tilt) + sa * ry * cos(tilt);
      final pr = (3 + sqrt(load) * 3.2).clamp(3.0, 15.0) * (.85 + .15 * sa);
      final toStar = (c - Offset(x, y));
      final dir = toStar / max(1, toStar.distance);
      canvas.drawCircle(
        Offset(x, y),
        pr,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(dir.dx * .5, dir.dy * .5),
            colors: [Color.lerp(color, Colors.white, .5)!, color, Color.lerp(color, Colors.black, .82)!],
            stops: const [0, .55, 1],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: pr)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PlanetsPainter old) => true;
}

/// Small helper so pages can rebuild every second (live timers).
class Every extends StatefulWidget {
  final Duration period;
  final WidgetBuilder builder;
  const Every({super.key, this.period = const Duration(seconds: 1), required this.builder});
  @override
  State<Every> createState() => _EveryState();
}

class _EveryState extends State<Every> {
  late final Stream<int> _s = Stream.periodic(widget.period, (i) => i);
  @override
  Widget build(BuildContext context) => StreamBuilder<int>(stream: _s, builder: (c, _) => widget.builder(c));
}

double starRadiusFor(double load) => .16 * (.8 + .55 * min(load, 1.1));
StarFx get fx => StarFx.instance;
