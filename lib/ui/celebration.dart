import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

OverlayEntry? _current;

void showCelebration(BuildContext context, {required String big, required String line, required String small}) {
  _current?.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Celebration(big: big, line: line, small: small, onDone: () {
        if (_current == entry) {
          entry.remove();
          _current = null;
        }
      }));
  _current = entry;
  Overlay.of(context).insert(entry);
}

class _Celebration extends StatefulWidget {
  final String big, line, small;
  final VoidCallback onDone;
  const _Celebration({required this.big, required this.line, required this.small, required this.onDone});
  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward().whenComplete(widget.onDone);
  final _bits = List.generate(34, (i) {
    final r = Random();
    final a = r.nextDouble() * pi * 2;
    return (a, 120 + r.nextDouble() * 240, 3 + r.nextDouble() * 6, [C.ok, C.sky, const Color(0xFFFFD58A), Colors.white, C.violet][i % 5]);
  });

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDone,
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final v = c.value;
          final fadeOut = v > .82 ? 1 - (v - .82) / .18 : 1.0;
          final pop = Curves.elasticOut.transform((v / .35).clamp(0.0, 1.0));
          return Opacity(
            opacity: fadeOut.clamp(0.0, 1.0),
            child: Stack(children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6 * fadeOut, sigmaY: 6 * fadeOut),
                  child: Container(color: const Color(0x73020310)),
                ),
              ),
              Positioned.fill(child: CustomPaint(painter: _Bits(_bits, (v / .5).clamp(0.0, 1.0)))),
              Center(
                child: Transform.scale(
                  scale: .6 + .4 * pop,
                  child: Container(
                    width: 320,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                    decoration: BoxDecoration(
                      color: const Color(0xB3141630),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: C.ok.withValues(alpha: .4)),
                      boxShadow: [BoxShadow(color: C.ok.withValues(alpha: .25), blurRadius: 60)],
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(colors: [Colors.white, C.ok]).createShader(r),
                          child: Text('¡Hecho!', style: sora(44, w: FontWeight.w600, color: Colors.white, ls: -1.2)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: C.ok.withValues(alpha: .12), borderRadius: BorderRadius.circular(99), border: Border.all(color: C.ok.withValues(alpha: .4))),
                          child: Text(widget.big, style: mono(18, w: FontWeight.w500, color: C.ok)),
                        ),
                        const SizedBox(height: 12),
                        Text(widget.line, textAlign: TextAlign.center, style: sora(17, w: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text(widget.small, textAlign: TextAlign.center, style: mono(12, color: C.muted)),
                      ]),
                    ),
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

class _Bits extends CustomPainter {
  final List<(double, double, double, Color)> bits;
  final double k;
  _Bits(this.bits, this.k);
  @override
  void paint(Canvas canvas, Size size) {
    if (k <= 0 || k >= 1) return;
    final c = Offset(size.width / 2, size.height * .46);
    final e = Curves.easeOutCubic.transform(k);
    for (final (a, dist, s, col) in bits) {
      final p = c + Offset(cos(a), sin(a) - .25) * dist * e;
      final alpha = (1 - k).clamp(0.0, 1.0);
      canvas.drawCircle(p, s * (1 - .6 * k), Paint()
        ..color = col.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _Bits old) => true;
}
