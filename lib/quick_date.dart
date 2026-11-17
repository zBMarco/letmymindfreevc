/// Quick capture: finds a date and/or time written in Spanish inside a task title
/// ("pagar la luz mañana 5pm", "dentista el viernes a las 10", "reporte 15 dic")
/// and returns the title without it plus the deadline.
library;

import 'models.dart';

class QuickDate {
  /// Title with the date words removed.
  final String title;
  final DateTime due;

  /// The words that were understood, as written (e.g. "mañana 5pm").
  final String matched;
  const QuickDate(this.title, this.due, this.matched);
}

const _monthKeys = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _dayKeys = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
const _numWords = {'un': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10};

/// Same length as the input, so match positions line up with the original text.
String _fold(String s) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}

int _num(String s) => int.tryParse(s) ?? _numWords[s] ?? 1;

QuickDate? parseQuickDate(String input, [DateTime? now]) {
  now ??= DateTime.now();
  var norm = _fold(input);
  final spans = <(int, int)>[];

  RegExpMatch? take(String pattern) {
    final m = RegExp(pattern).firstMatch(norm);
    if (m == null) return null;
    spans.add((m.start, m.end));
    norm = norm.replaceRange(m.start, m.end, ' ' * (m.end - m.start));
    return m;
  }

  DateTime? day; // date only (at midnight)
  int? hour, minute;
  DateTime? exact; // "en 2 horas"
  final today = DateTime(now.year, now.month, now.day);

  // ---- relative amounts: "en 3 días", "en 2 horas", "en una semana"
  final rel = take(r'\b(?:dentro de|en) (\d{1,3}|un|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez) (minutos?|min|horas?|hrs?|dias?|semanas?|mes(?:es)?)\b');
  if (rel != null) {
    final n = _num(rel[1]!);
    final unit = rel[2]!;
    if (unit.startsWith('min')) {
      exact = now.add(Duration(minutes: n));
    } else if (unit.startsWith('h')) {
      exact = now.add(Duration(hours: n));
    } else if (unit.startsWith('dia')) {
      day = DateTime(today.year, today.month, today.day + n);
    } else if (unit.startsWith('semana')) {
      day = DateTime(today.year, today.month, today.day + 7 * n);
    } else {
      day = DateTime(today.year, today.month + n, today.day);
    }
  }

  // ---- time of day words (before plain "mañana", which is "tomorrow")
  String? partOfDay;
  final pod = take(r'\b(?:en|por|de) la (manana|tarde|noche)\b');
  if (pod != null) partOfDay = pod[1];

  // ---- the date
  if (day == null && exact == null) {
    if (take(r'\bpasado manana\b') != null) {
      day = DateTime(today.year, today.month, today.day + 2);
    } else if (take(r'\bmanana\b') != null) {
      day = DateTime(today.year, today.month, today.day + 1);
    } else if (take(r'\bhoy\b') != null) {
      day = today;
    } else if (take(r'\b(?:la )?(?:proxima semana|semana que viene)\b') != null) {
      day = DateTime(today.year, today.month, today.day + 8 - today.weekday); // next Monday
    } else {
      final wd = take(r'\b(?:el |este |esta )?(?:proximo |pr[oó]xima )?(lunes|martes|miercoles|jueves|viernes|sabado|domingo)(?: que viene| proximo)?\b');
      if (wd != null) {
        final target = _dayKeys.indexOf(wd[1]!) + 1;
        var diff = (target - today.weekday) % 7;
        if (diff == 0) diff = 7;
        day = DateTime(today.year, today.month, today.day + diff);
      } else {
        final named = take(r'\b(?:el )?(\d{1,2})(?: de)? (ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic)[a-z]*\.?(?:(?: de)? (\d{4}))?\b');
        final slash = named == null ? take(r'\b(?:el )?(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b') : null;
        final m = named ?? slash;
        if (m != null) {
          final d = int.parse(m[1]!);
          final mo = named != null ? (m[2] == 'set' ? 9 : _monthKeys.indexOf(m[2]!) + 1) : int.parse(m[2]!);
          var y = m[3] != null ? int.parse(m[3]!) : today.year;
          if (y < 100) y += 2000;
          if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
            var cand = DateTime(y, mo, d);
            if (m[3] == null && cand.isBefore(today)) cand = DateTime(y + 1, mo, d);
            if (cand.month == mo) day = cand; // rejects 31/2
          }
        }
      }
    }
  }

  // ---- the time
  if (exact == null) {
    if (take(r'\b(?:al |a )?(?:mediodia|medio dia)\b') != null) {
      hour = 12;
      minute = 0;
    } else if (take(r'\b(?:a la )?medianoche\b') != null) {
      hour = 23;
      minute = 59;
    } else {
      final ampm = take(r'(?:\b(?:a las?|para las?) )?\b(\d{1,2})(?::(\d{2}))? ?(am|pm|a\. ?m\.|p\. ?m\.)(?=\s|$|[,.;!?])');
      if (ampm != null) {
        var h = int.parse(ampm[1]!);
        final pm = ampm[3]!.startsWith('p');
        if (h <= 12) {
          if (pm && h < 12) h += 12;
          if (!pm && h == 12) h = 0;
          hour = h;
          minute = int.tryParse(ampm[2] ?? '') ?? 0;
        }
      } else {
        final at = take(r'\b(?:a las?|para las?) (\d{1,2})(?::(\d{2}))?(?: ?(?:hrs?|horas)\b)?(?: (?:de la )?(manana|tarde|noche))?\b') ??
            take(r'\b(\d{1,2}):(\d{2})(?: ?(?:hrs?|horas)\b)?(?: (?:de la )?(manana|tarde|noche))?\b');
        if (at != null) {
          var h = int.parse(at[1]!);
          final mi = int.tryParse(at[2] ?? '') ?? 0;
          final part = at[3] ?? partOfDay;
          if (h <= 23 && mi <= 59) {
            if ((part == 'tarde' || part == 'noche') && h < 12) h += 12;
            // "a las 5" with nothing else almost always means the afternoon
            if (part == null && at[2] == null && h >= 1 && h <= 7) h += 12;
            hour = h;
            minute = mi;
          }
        }
      }
    }
    if (hour == null && partOfDay != null) {
      hour = switch (partOfDay) { 'manana' => 9, 'tarde' => 17, _ => 20 };
      minute = 0;
    }
  }

  if (exact == null && day == null && hour == null) return null;

  DateTime due;
  if (exact != null) {
    due = exact;
  } else if (day != null) {
    if (hour != null) {
      due = DateTime(day.year, day.month, day.day, hour, minute ?? 0);
    } else {
      due = DateTime(day.year, day.month, day.day, 10);
      // "hoy" with no time: give it until the evening, never a deadline that already passed
      if (!due.isAfter(now)) due = DateTime(day.year, day.month, day.day, 20);
      if (!due.isAfter(now)) due = DateTime(day.year, day.month, day.day, 23, 59);
    }
  } else {
    due = DateTime(today.year, today.month, today.day, hour!, minute ?? 0);
    if (!due.isAfter(now)) due = DateTime(today.year, today.month, today.day + 1, hour, minute ?? 0);
  }

  spans.sort((a, b) => a.$1.compareTo(b.$1));
  var title = input;
  for (final (s, e) in spans.reversed) {
    title = title.replaceRange(s, e, ' ');
  }
  final matched = spans.map((s) => input.substring(s.$1, s.$2).trim()).join(' ');
  return QuickDate(_tidy(title), due, matched);
}

/// Removes connectors left hanging where the date used to be ("pagar la luz para").
String _tidy(String s) {
  var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final dangling = RegExp(r'(?:^|\s)(?:para el|para la|para|antes del|antes de|hasta el|hasta|el dia|el|la|a|de|del|en|este|esta|,|-|·)$', caseSensitive: false);
  while (true) {
    final next = t.replaceFirst(dangling, '').trim();
    if (next == t) break;
    t = next;
  }
  t = t.replaceAll(RegExp(r'\s+([,.;])'), r'$1').replaceAll(RegExp(r'[,;\-·]+$'), '').trim();
  return t;
}

/// "mañana 17:00", "vie 21 nov 10:00".
String describeDue(DateTime due, [DateTime? now]) {
  now ??= DateTime.now();
  final t = due.millisecondsSinceEpoch;
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(due.year, due.month, due.day);
  final diff = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final day = switch (diff) {
    0 => 'hoy',
    1 => 'mañana',
    2 => 'pasado mañana',
    _ => fmtDate(t),
  };
  return '$day ${fmtTime(t)}';
}
