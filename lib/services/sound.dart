import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Every sound in the app is synthesized here at startup (no audio files shipped),
/// written to WAV in the temp folder and played with audioplayers.
class SoundEngine {
  SoundEngine._();
  static final instance = SoundEngine._();

  static const _sr = 32000;
  final Map<String, String> _files = {};
  final Map<String, Uint8List> _bytes = {}; // web: played from memory
  bool _humPlaying = false;
  final List<AudioPlayer> _fx = [];
  int _next = 0;
  AudioPlayer? _hum;
  int _humLevel = -1;
  bool enabled = true;
  bool _ready = false;

  Future<void> init() async {
    try {
      final banks = await compute(renderAllSounds, 0);
      if (kIsWeb) {
        _bytes.addAll(banks);
      } else {
        await AudioPlayer.global.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: true).build(),
        );
        final dir = await getTemporaryDirectory();
        for (final e in banks.entries) {
          final f = File('${dir.path}/estrella_${e.key}.wav');
          await f.writeAsBytes(e.value, flush: true);
          _files[e.key] = f.path;
        }
      }
      for (var i = 0; i < 4; i++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        _fx.add(p);
      }
      _hum = AudioPlayer();
      await _hum!.setReleaseMode(ReleaseMode.loop);
      _ready = true;
    } catch (e) {
      debugPrint('Sonido no disponible: $e');
    }
  }

  Source? _src(String name) {
    if (kIsWeb) {
      final b = _bytes[name];
      return b == null ? null : BytesSource(b, mimeType: 'audio/wav');
    }
    final path = _files[name];
    return path == null ? null : DeviceFileSource(path);
  }

  Future<void> play(String name, {double volume = 1}) async {
    if (!_ready || !enabled) return;
    final src = _src(name);
    if (src == null) return;
    final p = _fx[_next++ % _fx.length];
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.play(src);
    } catch (_) {}
    // Safari only lets audio start after a tap, so the hum may have been
    // refused at launch; every tap-driven sound retries it.
    if (kIsWeb && !_humPlaying && _humLevel >= 0) {
      final lvl = _humLevel;
      _humLevel = -2;
      setHum(lvl);
    }
  }

  /// Ambient hum of the star. level: 0..4 (radiant..at the limit), -1 = silence (nebula / off).
  Future<void> setHum(int level) async {
    if (!_ready) return;
    final target = enabled ? level : -1;
    if (target == _humLevel) return;
    _humLevel = target;
    final h = _hum!;
    try {
      if (_humPlaying) await _fade(h, 0, 400);
      await h.stop();
      _humPlaying = false;
      if (target < 0) return;
      await h.setVolume(0);
      await h.play(_src('hum$target')!);
      _humPlaying = true;
      await _fade(h, .55, 900);
    } catch (_) {
      _humPlaying = false;
    }
  }

  Future<void> _fade(AudioPlayer p, double to, int ms) async {
    final from = p.volume;
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: ms ~/ steps));
      await p.setVolume(from + (to - from) * i / steps);
    }
  }
}

/* ======================= synthesis (runs in an isolate) ======================= */

@visibleForTesting
Map<String, Uint8List> renderAllSounds(int _) {
  final out = <String, Uint8List>{};
  out['flare'] = _wav(_flare());
  out['boom'] = _wav(_boom());
  out['rebirth'] = _wav(_rebirth());
  out['chime'] = _wav(_chime());
  out['tick'] = _wav(_tick());
  out['add'] = _wav(_add());
  for (var i = 0; i < 4; i++) {
    out['hum$i'] = _wav(_hum(i / 3.0));
  }
  return out;
}

const _sr = SoundEngine._sr;
final _r = Random(7);

Float64List _buf(double secs) => Float64List((secs * _sr).round());
double _noise() => _r.nextDouble() * 2 - 1;
double _expSweep(double a, double b, double k) => a * pow(b / a, k.clamp(0.0, 1.0));

/// attack/decay envelope with exponential shape.
double _env(double t, double a, double d) {
  if (t < 0) return 0;
  if (t < a) return t / a;
  return exp(-(t - a) / max(1e-4, d) * 5);
}

/// Chamberlin state-variable filter.
class _Svf {
  double low = 0, band = 0;
  double process(double x, double fc, double q, {String mode = 'low'}) {
    final f = 2 * sin(pi * min(fc, _sr / 6) / _sr);
    final high = x - low - q * band;
    band += f * high;
    low += f * band;
    return mode == 'low' ? low : mode == 'band' ? band : high;
  }
}

/// Small Schroeder reverb so effects sit in "space".
Float64List _reverb(Float64List dry, double wet, {double size = 1}) {
  final n = dry.length;
  final o = Float64List(n);
  final combs = [1557, 1617, 1491, 1422].map((d) => (d * size).round()).toList();
  for (final d in combs) {
    final b = Float64List(d);
    var i = 0;
    double lp = 0;
    for (var s = 0; s < n; s++) {
      final y = b[i];
      lp = y * .7 + lp * .3;
      b[i] = dry[s] + lp * .84;
      o[s] += y * .25;
      i = (i + 1) % d;
    }
  }
  for (final d in [225, 556]) {
    final b = Float64List(d);
    var i = 0;
    for (var s = 0; s < n; s++) {
      final bo = b[i];
      final y = -o[s] + bo;
      b[i] = o[s] + bo * .5;
      o[s] = y;
      i = (i + 1) % d;
    }
  }
  final res = Float64List(n);
  for (var s = 0; s < n; s++) {
    res[s] = dry[s] + o[s] * wet;
  }
  return res;
}

Float64List _flare() {
  final b = _buf(3.2);
  double ph = 0;
  final bp = _Svf(), lp = _Svf(), hp = _Svf();
  final crackles = List.generate(40, (_) => (.15 + _r.nextDouble() * _r.nextDouble() * 1.6, .05 + _r.nextDouble() * .3));
  for (var i = 0; i < b.length; i++) {
    final t = i / _sr;
    // impact: deep sine drop
    ph += 2 * pi * _expSweep(95, 32, t / .7) / _sr;
    var s = sin(ph) * _env(t, .006, .9) * .9;
    // plasma whoosh: band-passed noise sweeping up then down
    final fc = t < 1.1 ? _expSweep(250, 2600, t / 1.1) : _expSweep(2600, 600, (t - 1.1) / 1.3);
    s += bp.process(_noise(), fc, .9, mode: 'band') * _env(t, .22, 1.9) * .8;
    // rumble tail
    s += lp.process(_noise(), 130, 1.2) * _env(t - .1, .15, 2.2) * 1.4;
    // crackle
    var c = 0.0;
    for (final (at, p) in crackles) {
      final dt = t - at;
      if (dt >= 0 && dt < .05) c += p * exp(-dt * 120);
    }
    s += hp.process(_noise(), 3200, 1, mode: 'high') * c;
    b[i] = s;
  }
  return _reverb(b, .5);
}

Float64List _boom() {
  final b = _buf(5);
  double ph1 = 0, ph2 = 0;
  final lp = _Svf();
  for (var i = 0; i < b.length; i++) {
    final t = i / _sr;
    ph1 += 2 * pi * _expSweep(1400, 50, t / .35) / _sr;
    var s = ((ph1 / pi) % 2 - 1) * _env(t, .01, .4) * .25;
    final t2 = t - .2;
    if (t2 > 0) {
      ph2 += 2 * pi * _expSweep(70, 18, t2 / 3.5) / _sr;
      s += sin(ph2) * _env(t2, .02, 3.6);
      final n = _tanh(_noise() * 3);
      s += lp.process(n, _expSweep(7000, 70, t2 / 3.6), 1.1) * _env(t2, .015, 3.6) * 1.1;
    }
    b[i] = s;
  }
  return _reverb(b, .8, size: 1.3);
}

double _tanh(double x) {
  final e = exp(2 * x);
  return (e - 1) / (e + 1);
}

Float64List _rebirth() {
  final b = _buf(5);
  const freqs = [261.6, 392.0, 523.3, 659.3, 784.0, 1046.5];
  final hp = _Svf();
  for (var i = 0; i < b.length; i++) {
    final t = i / _sr;
    var s = 0.0;
    for (var k = 0; k < freqs.length; k++) {
      final st = t - (.5 + k * .13);
      if (st < 0) continue;
      final e = _env(st, .5, 3) * .09;
      s += (sin(2 * pi * freqs[k] * st) + .5 * _tri(freqs[k] * 1.003 * st)) * e;
    }
    s += hp.process(_noise(), _expSweep(800, 7000, t / 1.4), 1, mode: 'high') * _env(t, 1, 1.2) * .12;
    b[i] = s;
  }
  return _reverb(b, .9, size: 1.2);
}

double _tri(double x) => 4 * ((x % 1) - .5).abs() - 1;

Float64List _chime() {
  final b = _buf(2.4);
  const freqs = [1046.5, 1568.0, 2093.0];
  for (var i = 0; i < b.length; i++) {
    final t = i / _sr;
    var s = 0.0;
    for (var k = 0; k < 3; k++) {
      final st = t - k * .06;
      if (st < 0) continue;
      s += sin(2 * pi * freqs[k] * st) * _env(st, .004, 1.6) * .16 / (k + 1);
    }
    b[i] = s;
  }
  return _reverb(b, .8);
}

Float64List _tick() {
  final b = _buf(.6);
  for (var i = 0; i < b.length; i++) {
    final t = i / _sr;
    b[i] = sin(2 * pi * 1760 * t) * _env(t, .002, .12) * .18 + sin(2 * pi * 2637 * t) * _env(t, .002, .08) * .08;
  }
  return _reverb(b, .5);
}

Float64List _add() {
  final b = _buf(1.2);
  final bp = _Svf();
  for (var i = 0; i < b.length; i++) {
    final t = i / _sr;
    b[i] = bp.process(_noise(), _expSweep(400, 1800, t / .5), .8, mode: 'band') * _env(t, .12, .5) * .35 +
        sin(2 * pi * 523.3 * t) * _env(t - .15, .01, .6) * .05;
  }
  return _reverb(b, .6);
}

/// Seamless 4 s loop. L: 0 calm .. 1 at the limit (deeper, rougher, faster tremolo).
Float64List _hum(double L) {
  const secs = 4.0;
  final n = (secs * _sr).round();
  final b = Float64List(n);
  double q(double f) => (f * secs).round() / secs; // snap to the loop length so it repeats cleanly
  final f1 = q(58 - L * 18), f2 = q(58.5 - L * 16.5), f3 = q(116 - L * 30), trem = q(.25 + L * 3);
  final lp = _Svf();
  final noise = Float64List(n);
  for (var i = 0; i < n; i++) {
    noise[i] = lp.process(_noise(), 140 + L * 700, 1.2);
  }
  // crossfade the noise end into its start so the loop seam is inaudible
  const xf = 4000;
  for (var i = 0; i < xf; i++) {
    final k = i / xf;
    noise[i] = noise[i] * k + noise[n - xf + i] * (1 - k);
  }
  for (var i = 0; i < n; i++) {
    final t = i / _sr;
    final tr = 1 + .25 * sin(2 * pi * trem * t);
    b[i] = (sin(2 * pi * f1 * t) * .45 + sin(2 * pi * f2 * t) * .45 + _tri(f3 * t) * .12 + noise[i] * (1.2 + L)) * tr * .5;
  }
  return b;
}

Uint8List _wav(Float64List s) {
  var peak = 1e-6;
  for (final v in s) {
    peak = max(peak, v.abs());
  }
  final g = .89 / peak;
  final n = s.length;
  final bytes = ByteData(44 + n * 2);
  void str(int o, String x) {
    for (var i = 0; i < x.length; i++) {
      bytes.setUint8(o + i, x.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  bytes.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, _sr, Endian.little);
  bytes.setUint32(28, _sr * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  str(36, 'data');
  bytes.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    bytes.setInt16(44 + i * 2, (s[i] * g * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return bytes.buffer.asUint8List();
}
