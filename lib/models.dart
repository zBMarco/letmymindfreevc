import 'dart:math';

final _rnd = Random();
String newId(String p) =>
    '$p-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 30).toRadixString(36)}';

int nowMs() => DateTime.now().millisecondsSinceEpoch;

const sizeNames = ['', 'Chica', 'Mediana', 'Grande', 'Enorme', 'Monstruo'];
const sizeHints = [
  '',
  'Algo rápido que igual da vueltas en tu cabeza',
  'Te toma un rato, molesta un poco',
  'Te pesa de verdad',
  'Te agobia solo pensarlo',
  'Te quita el sueño',
];

enum Repeat { none, daily, weekly, monthly }

const repeatNames = {Repeat.none: 'No', Repeat.daily: 'Diaria', Repeat.weekly: 'Semanal', Repeat.monthly: 'Mensual'};

class LogEntry {
  final int t;
  final String e;
  final String? x;
  LogEntry(this.t, this.e, [this.x]);
  Map<String, dynamic> toJson() => {'t': t, 'e': e, if (x != null) 'x': x};
  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(j['t'] as int, j['e'] as String, j['x'] as String?);
}

class SubTask {
  final String id;
  String text;
  bool done;
  SubTask({required this.id, required this.text, this.done = false});
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};
  factory SubTask.fromJson(Map<String, dynamic> j) =>
      SubTask(id: j['id'] as String, text: j['text'] as String, done: j['done'] as bool? ?? false);
}

class Task {
  final String id;
  String title;
  String? catId;
  int size;
  int? due;
  Repeat repeat;
  String notes;
  bool remind;
  List<SubTask> subs;
  int createdAt;
  int activeMs;
  int? runningSince;
  int? completedAt;
  int? showFrom;

  /// For a repeating task that was completed: the next occurrence it created.
  String? nextId;
  List<LogEntry> log;

  Task({
    required this.id,
    required this.title,
    this.catId,
    this.size = 2,
    this.due,
    this.repeat = Repeat.none,
    this.notes = '',
    this.remind = false,
    List<SubTask>? subs,
    required this.createdAt,
    this.activeMs = 0,
    this.runningSince,
    this.completedAt,
    this.showFrom,
    this.nextId,
    List<LogEntry>? log,
  })  : subs = subs ?? [],
        log = log ?? [];

  bool get isVisible => completedAt == null && !(showFrom != null && showFrom! > nowMs());
  bool get isOverdue => due != null && due! < nowMs() && completedAt == null;
  int get focusMs => activeMs + (runningSince != null ? nowMs() - runningSince! : 0);
  int get takenMs => activeMs > 0 ? activeMs : (completedAt ?? nowMs()) - createdAt;

  double get load {
    if (!isVisible) return 0;
    double l = size.toDouble();
    if (subs.isNotEmpty) l *= 1 - .6 * subs.where((s) => s.done).length / subs.length;
    if (isOverdue) l *= 2;
    return l;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'catId': catId,
        'size': size,
        'due': due,
        'repeat': repeat.name,
        'notes': notes,
        'remind': remind,
        'subs': subs.map((s) => s.toJson()).toList(),
        'createdAt': createdAt,
        'activeMs': activeMs,
        'runningSince': runningSince,
        'completedAt': completedAt,
        'showFrom': showFrom,
        if (nextId != null) 'nextId': nextId,
        'log': log.map((l) => l.toJson()).toList(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        catId: j['catId'] as String?,
        size: j['size'] as int? ?? 2,
        due: j['due'] as int?,
        repeat: Repeat.values.firstWhere((r) => r.name == j['repeat'], orElse: () => Repeat.none),
        notes: j['notes'] as String? ?? '',
        remind: j['remind'] as bool? ?? false,
        subs: (j['subs'] as List? ?? []).map((s) => SubTask.fromJson(Map<String, dynamic>.from(s))).toList(),
        createdAt: j['createdAt'] as int,
        activeMs: j['activeMs'] as int? ?? 0,
        runningSince: j['runningSince'] as int?,
        completedAt: j['completedAt'] as int?,
        showFrom: j['showFrom'] as int?,
        nextId: j['nextId'] as String?,
        log: (j['log'] as List? ?? []).map((l) => LogEntry.fromJson(Map<String, dynamic>.from(l))).toList(),
      );

  Task copy() => Task.fromJson(toJson());
}

class TaskType {
  final String id;
  String name;
  int color;
  int createdAt;
  TaskType({required this.id, required this.name, required this.color, required this.createdAt});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color, 'createdAt': createdAt};
  factory TaskType.fromJson(Map<String, dynamic> j) =>
      TaskType(id: j['id'] as String, name: j['name'] as String, color: j['color'] as int, createdAt: j['createdAt'] as int);
}

enum Phase { star, nebula }

class StarState {
  Phase phase;
  bool armed;
  int progress;
  int rebirths;
  int supernovas;
  int cap;
  StarState({this.phase = Phase.star, this.armed = true, this.progress = 0, this.rebirths = 0, this.supernovas = 0, this.cap = 20});
  Map<String, dynamic> toJson() =>
      {'phase': phase.name, 'armed': armed, 'progress': progress, 'rebirths': rebirths, 'supernovas': supernovas, 'cap': cap};
  factory StarState.fromJson(Map<String, dynamic> j) => StarState(
        phase: j['phase'] == 'nebula' ? Phase.nebula : Phase.star,
        armed: j['armed'] as bool? ?? true,
        progress: j['progress'] as int? ?? 0,
        rebirths: j['rebirths'] as int? ?? 0,
        supernovas: j['supernovas'] as int? ?? 0,
        cap: j['cap'] as int? ?? 20,
      );
}

class StarLevel {
  final double max;
  final String name;
  final String hint;
  final int color;
  const StarLevel(this.max, this.name, this.hint, this.color);
}

const starLevels = [
  StarLevel(.2, 'Radiante', 'Brilla fuerte. Vas muy ligero.', 0xFF9CC2FF),
  StarLevel(.5, 'Tranquila', 'Estable. Sigue soltando a tu ritmo.', 0xFFFFD58A),
  StarLevel(.75, 'Inquieta', 'Empieza a pulsar. Suelta algo chico hoy.', 0xFFFFA45C),
  StarLevel(1, 'Al límite', 'Está temblando. Si sigue creciendo, explota.', 0xFFFF6B5A),
  StarLevel(1e9, 'Supernova', 'Explotó. De la nebulosa nace una nueva.', 0xFFD7A8FF),
];

const rebirthNeed = 3;

const catPalette = [0xFF7CC8FF, 0xFFFF8FC8, 0xFF8EF0B8, 0xFFFFD27A, 0xFFC3A6FF, 0xFFFF9F7A];
const catSuggestions = [
  ('Trabajo', 0xFF7CC8FF),
  ('Casa', 0xFFFFD27A),
  ('Trámites', 0xFFFF9F7A),
  ('Salud', 0xFF8EF0B8),
  ('Dinero', 0xFFC3A6FF),
  ('Personas', 0xFFFF8FC8),
];

const celebrationLines = {
  1: ['Una menos.', 'Rápido y fuera.', 'Así se empieza.'],
  2: ['Eso ya no da vueltas en tu cabeza.', 'Bien. Siguiente.', 'Tu estrella respira mejor.'],
  3: ['Eso pesaba. Ya no.', 'Mira cómo avanzas.', 'Tu estrella se calmó un poco.'],
  4: ['Eso te agobiaba y lo resolviste.', 'Respira. Ya está hecho.', 'Tu estrella lo nota.'],
  5: ['Lo que te quitaba el sueño: HECHO.', 'Hoy duermes mejor.', 'Lo más difícil, y lo hiciste.'],
};

String dayKey(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return '${d.year}-${d.month}-${d.day}';
}

int startOfDay(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
}

String fmtDur(int ms) {
  final s = max(0, ms) ~/ 1000;
  if (s < 60) return '$s s';
  final m = s ~/ 60;
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  if (h < 24) return '$h h${m % 60 > 0 ? ' ${m % 60} min' : ''}';
  final d = h ~/ 24;
  return '$d d${h % 24 > 0 ? ' ${h % 24} h' : ''}';
}

String fmtClock(int ms) {
  final s = ms ~/ 1000, h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
  final ss = x.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

String two(int n) => n.toString().padLeft(2, '0');
String fmtWhen(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return '${d.day} ${_months[d.month - 1]} ${two(d.hour)}:${two(d.minute)}';
}

String fmtTime(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return '${two(d.hour)}:${two(d.minute)}';
}

String fmtDate(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return '${d.day} ${_months[d.month - 1]}';
}

String fmtDay(int t) {
  final k = dayKey(t);
  if (k == dayKey(nowMs())) return 'Hoy';
  if (k == dayKey(nowMs() - 86400000)) return 'Ayer';
  final d = DateTime.fromMillisecondsSinceEpoch(t);
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/* ============================== metas y racha ============================== */

class Goal {
  final String id;
  String title;
  String why;
  int color;
  int? target;
  int createdAt;
  int? achievedAt;

  /// dayKey() of every day you checked this goal.
  Set<String> days;

  Goal({required this.id, required this.title, this.why = '', required this.color, this.target, required this.createdAt, this.achievedAt, Set<String>? days})
      : days = days ?? {};

  bool get active => achievedAt == null;
  bool get doneToday => days.contains(dayKey(nowMs()));

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'why': why,
        'color': color,
        'target': target,
        'createdAt': createdAt,
        'achievedAt': achievedAt,
        'days': days.toList(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        title: j['title'] as String,
        why: j['why'] as String? ?? '',
        color: j['color'] as int? ?? catPalette[0],
        target: j['target'] as int?,
        createdAt: j['createdAt'] as int,
        achievedAt: j['achievedAt'] as int?,
        days: {...(j['days'] as List? ?? []).cast<String>()},
      );
}

/// Your streak: every task you completed in the current run of consecutive days,
/// ending today, or yesterday if you haven't finished one today yet (the streak is
/// still alive until the day ends). [perDay] maps dayKey() to tasks done that day.
int streakOf(Map<String, int> perDay, [DateTime? now]) {
  int on(DateTime d) => perDay[dayKey(d.millisecondsSinceEpoch)] ?? 0;
  var d = now ?? DateTime.now();
  if (on(d) == 0) d = DateTime(d.year, d.month, d.day - 1, 12);
  var n = 0;
  while (on(d) > 0) {
    n += on(d);
    d = DateTime(d.year, d.month, d.day - 1, 12);
  }
  return n;
}

/// The most tasks you ever completed in one run of consecutive days.
int bestStreakOf(Map<String, int> perDay) {
  DateTime parse(String k) {
    final p = k.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2], 12);
  }

  final dates = [
    for (final e in perDay.entries)
      if (e.value > 0) (parse(e.key), e.value),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  var best = 0, run = 0;
  for (var i = 0; i < dates.length; i++) {
    final prev = i == 0 ? null : dates[i - 1].$1;
    final next = prev == null ? null : DateTime(prev.year, prev.month, prev.day + 1, 12);
    final follows = next != null && dates[i].$1.year == next.year && dates[i].$1.month == next.month && dates[i].$1.day == next.day;
    run = (follows ? run : 0) + dates[i].$2;
    best = max(best, run);
  }
  return best;
}

/// A constellation you earn when your streak reaches [tasks]. Points live in a 0..1 square.
class Reward {
  final int tasks;
  final String name;
  final String line;
  final int color;
  final List<(double, double)> pts;
  final List<(int, int)> edges;
  const Reward(this.tasks, this.name, this.line, this.color, this.pts, this.edges);
}

const rewards = [
  Reward(3, 'Triángulo', 'Tres tareas de racha. Ya empezaste a dibujar tu cielo.', 0xFF9CC2FF,
      [(.2, .75), (.8, .62), (.45, .2)], [(0, 1), (1, 2), (2, 0)]),
  Reward(7, 'Casiopea', 'Siete tareas sin soltar la racha. Eso ya es constancia.', 0xFFFFD58A,
      [(.08, .35), (.3, .7), (.5, .42), (.7, .75), (.92, .3)], [(0, 1), (1, 2), (2, 3), (3, 4)]),
  Reward(14, 'Lira', 'Catorce tareas. Tu disciplina ya suena.', 0xFF8EF0B8,
      [(.5, .1), (.4, .38), (.62, .42), (.33, .85), (.58, .9)], [(0, 1), (0, 2), (1, 2), (1, 3), (2, 4), (3, 4)]),
  Reward(21, 'Cisne', 'Veintiuna tareas: así nace un hábito.', 0xFFC3A6FF,
      [(.5, .08), (.5, .4), (.5, .7), (.5, .95), (.12, .3), (.88, .48)], [(0, 1), (1, 2), (2, 3), (4, 1), (1, 5)]),
  Reward(30, 'Osa Menor', 'Treinta tareas. Ya tienes tu propia estrella polar.', 0xFF7CC8FF,
      [(.1, .2), (.28, .3), (.42, .42), (.55, .55), (.6, .82), (.88, .85), (.85, .58)], [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 3)]),
  Reward(50, 'Osa Mayor', 'Cincuenta tareas. Esto ya es parte de ti.', 0xFFFF8FC8,
      [(.05, .3), (.22, .35), (.38, .42), (.52, .52), (.55, .82), (.9, .85), (.92, .55)], [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 3)]),
  Reward(75, 'León', 'Setenta y cinco tareas con el corazón de un león.', 0xFFFFB86B,
      [(.18, .3), (.25, .12), (.4, .1), (.35, .45), (.3, .7), (.62, .6), (.92, .78), (.75, .42)], [(0, 1), (1, 2), (0, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 3)]),
  Reward(100, 'Orión', 'Cien tareas. Eres el cazador de tus metas.', 0xFFFF7A6B,
      [(.28, .1), (.72, .15), (.42, .5), (.5, .48), (.58, .46), (.25, .9), (.75, .88), (.5, .05)], [(0, 2), (1, 4), (2, 3), (3, 4), (2, 5), (4, 6), (0, 7), (7, 1)]),
  Reward(150, 'Escorpión', 'Ciento cincuenta tareas. Nada te detiene.', 0xFFFF6BD5,
      [(.88, .1), (.8, .25), (.68, .35), (.55, .45), (.45, .6), (.4, .78), (.25, .9), (.1, .82), (.12, .65)], [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8)]),
  Reward(200, 'Andrómeda', 'Doscientas tareas. Tu cielo ya tiene galaxias.', 0xFFB79CFF,
      [(.05, .7), (.3, .6), (.55, .48), (.82, .35), (.45, .25), (.62, .75), (.7, .1)], [(0, 1), (1, 2), (2, 3), (2, 4), (4, 6), (1, 5)]),
  Reward(365, 'Fénix', 'Trescientas sesenta y cinco tareas. Renaciste con tus metas.', 0xFFFFE08A,
      [(.5, .08), (.5, .35), (.15, .2), (.85, .2), (.05, .5), (.95, .5), (.5, .62), (.35, .92), (.65, .92)], [(0, 1), (1, 2), (1, 3), (2, 4), (3, 5), (1, 6), (6, 7), (6, 8)]),
];

/// The streak flame heats up like a star: red embers, then orange, yellow, white,
/// blue and finally violet, the hottest.
class FlameTier {
  final int from;
  final String name;
  final int base; // bottom of the flame
  final int tip; // top of the flame
  const FlameTier(this.from, this.name, this.base, this.tip);
}

const flameTiers = [
  FlameTier(0, 'Apagado', 0xFF6F75A0, 0xFF6F75A0),
  FlameTier(1, 'Brasa', 0xFFE8452C, 0xFFFF8A5C),
  FlameTier(3, 'Fuego naranja', 0xFFFF6A1F, 0xFFFFB86B),
  FlameTier(7, 'Fuego amarillo', 0xFFFF9A1F, 0xFFFFE66B),
  FlameTier(14, 'Fuego blanco', 0xFFFFC46B, 0xFFFFFBEA),
  FlameTier(30, 'Fuego azul', 0xFF2F7BFF, 0xFF9EE6FF),
  FlameTier(100, 'Fuego violeta', 0xFF7A3CFF, 0xFFE0B0FF),
  FlameTier(365, 'Fuego estelar', 0xFFFF4FD8, 0xFF7CF0FF),
];

/// Index in [flameTiers] for a streak of [n] tasks.
int flameTierOf(int n) {
  var i = 0;
  while (i + 1 < flameTiers.length && n >= flameTiers[i + 1].from) {
    i++;
  }
  return i;
}

const goalCheers = [
  'Un día más. Así se construye.',
  'Constancia > motivación.',
  'Tu yo del futuro te lo agradece.',
  'Pequeño paso, gran racha.',
  'No rompas la cadena.',
  'Hoy cumpliste. Eso cuenta.',
];
