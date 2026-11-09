import 'package:flutter_test/flutter_test.dart';
import 'package:mi_estrella/services/sound.dart';

void main() {
  test('se sintetizan todos los sonidos como WAV válidos', () {
    final sw = Stopwatch()..start();
    final bank = renderAllSounds(0);
    sw.stop();
    expect(bank.keys.toSet(), {'flare', 'boom', 'rebirth', 'chime', 'tick', 'add', 'hum0', 'hum1', 'hum2', 'hum3'});
    for (final e in bank.entries) {
      final b = e.value;
      expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF', reason: e.key);
      expect(b.length, greaterThan(44 + 1000), reason: e.key);
      // not silent
      var peak = 0;
      for (var i = 44; i < b.length; i += 2) {
        final v = (b[i] | (b[i + 1] << 8)).toSigned(16).abs();
        if (v > peak) peak = v;
      }
      expect(peak, greaterThan(20000), reason: e.key);
    }
    // ignore: avoid_print
    print('Síntesis: ${sw.elapsedMilliseconds} ms');
  });
}
