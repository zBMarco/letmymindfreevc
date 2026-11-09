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
