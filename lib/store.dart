import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services/reminders.dart';

/// Things that happened that the UI turns into light, sound and haptics.
sealed class StarEvent {}

class TaskCompleted extends StarEvent {
  final Task task;
  final int pctFreed;
  final bool inNebula;
  TaskCompleted(this.task, this.pctFreed, this.inNebula);
}

class Supernova extends StarEvent {}

class Rebirth extends StarEvent {}

class AppStore extends ChangeNotifier {
  static const _key = 'miestrella.v1';
  final Map<String, Task> tasks = {};
  final Map<String, TaskType> cats = {};
  StarState star = StarState();
  bool sound = true;
  bool haptics = true;
  String? lastCat;

  final _events = StreamController<StarEvent>.broadcast();
  Stream<StarEvent> get events => _events.stream;

  SharedPreferences? _prefs;
  Timer? _minute;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final t in (j['tasks'] as List? ?? [])) {
          final task = Task.fromJson(Map<String, dynamic>.from(t));
          tasks[task.id] = task;
        }
        for (final c in (j['cats'] as List? ?? [])) {
          final cat = TaskType.fromJson(Map<String, dynamic>.from(c));
          cats[cat.id] = cat;
        }
        if (j['star'] != null) star = StarState.fromJson(Map<String, dynamic>.from(j['star']));
        sound = j['sound'] as bool? ?? true;
        haptics = j['haptics'] as bool? ?? true;
        lastCat = j['lastCat'] as String?;
      } catch (e) {
        debugPrint('No se pudieron leer los datos: $e');
      }
    }
    _minute = Timer.periodic(const Duration(seconds: 30), (_) {
      checkStar();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    _events.close();
    super.dispose();
  }

  void _save() {
    final j = {
      'tasks': tasks.values.map((t) => t.toJson()).toList(),
      'cats': cats.values.map((c) => c.toJson()).toList(),
      'star': star.toJson(),
      'sound': sound,
      'haptics': haptics,
      'lastCat': lastCat,
    };
    _prefs?.setString(_key, jsonEncode(j));
  }

  void _commit() {
    _save();
    notifyListeners();
  }

  /* ---------- derived ---------- */
  double get load => tasks.values.fold<double>(0, (a, t) => a + t.load) / max(1, star.cap);
  StarLevel get level => star.phase == Phase.nebula ? starLevels[4] : starLevels.firstWhere((s) => load <= s.max, orElse: () => starLevels[3]);
  List<TaskType> get sortedCats => cats.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  TaskType? catOf(Task t) => t.catId == null ? null : cats[t.catId];
  int pctOf(double l) => (l / max(1, star.cap) * 100).round();

  List<Task> pending({String? filter}) {
    final list = tasks.values.where((t) => t.isVisible && (filter == null || t.catId == filter)).toList();
    list.sort((a, b) {
      final r = (b.runningSince != null ? 1 : 0) - (a.runningSince != null ? 1 : 0);
      if (r != 0) return r;
      final o = (b.isOverdue ? 1 : 0) - (a.isOverdue ? 1 : 0);
      if (o != 0) return o;
      final l = b.load.compareTo(a.load);
      if (l != 0) return l;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  List<Task> get upcoming =>
      tasks.values.where((t) => t.completedAt == null && t.showFrom != null && t.showFrom! > nowMs()).toList()
        ..sort((a, b) => a.showFrom!.compareTo(b.showFrom!));

  List<Task> get done => tasks.values.where((t) => t.completedAt != null).toList()..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

  List<Task> get doneToday => done.where((t) => dayKey(t.completedAt!) == dayKey(nowMs())).toList();

  int get streak {
    final days = done.map((t) => dayKey(t.completedAt!)).toSet();
    var d = DateTime.now();
    if (!days.contains(dayKey(d.millisecondsSinceEpoch))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(dayKey(d.millisecondsSinceEpoch))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  double catLoad(String id) => tasks.values.where((t) => t.catId == id).fold<double>(0, (a, t) => a + t.load);

  /* ---------- star lifecycle ---------- */
  void checkStar() {
    final l = load;
    if (star.phase == Phase.star && l > 1 && star.armed) {
      star
        ..phase = Phase.nebula
        ..progress = 0
        ..supernovas += 1
        ..armed = false;
      _commit();
      _events.add(Supernova());
    } else if (star.phase == Phase.star && !star.armed && l <= 1) {
      star.armed = true;
      _commit();
    }
  }

  /* ---------- tasks ---------- */
  Task addTask({required String title, String? catId, int size = 2, int? due, Repeat repeat = Repeat.none, String notes = '', bool remind = false}) {
    final n = nowMs();
    final t = Task(
      id: newId('t'),
      title: title,
      catId: catId,
      size: size,
      due: due,
      repeat: repeat,
      notes: notes,
      remind: remind && due != null,
      createdAt: n,
      log: [LogEntry(n, 'created')],
    );
    tasks[t.id] = t;
    lastCat = catId;
    _commit();
    Reminders.instance.schedule(t);
    checkStar();
    return t;
  }

  void updateTask(String id, {required String title, String? catId, required int size, int? due, required Repeat repeat, required String notes, required bool remind}) {
    final t = tasks[id];
    if (t == null) return;
    t
      ..title = title
      ..catId = catId
      ..size = size
      ..due = due
      ..repeat = repeat
      ..notes = notes
      ..remind = remind && due != null
      ..log.add(LogEntry(nowMs(), 'edited'));
    _commit();
    Reminders.instance.schedule(t);
    checkStar();
  }

  void start(String id) {
    final t = tasks[id];
    if (t == null || t.runningSince != null) return;
    t.runningSince = nowMs();
    t.log.add(LogEntry(nowMs(), 'started'));
    _commit();
  }

  void pause(String id) {
    final t = tasks[id];
    if (t == null || t.runningSince == null) return;
    t.activeMs += nowMs() - t.runningSince!;
    t.runningSince = null;
    t.log.add(LogEntry(nowMs(), 'paused'));
    _commit();
  }

  void complete(String id) {
    final t = tasks[id];
    if (t == null || t.completedAt != null) return;
    final freed = pctOf(t.load);
    final n = nowMs();
    if (t.runningSince != null) t.activeMs += n - t.runningSince!;
    t.runningSince = null;
    t.completedAt = n;
    t.log.add(LogEntry(n, 'done'));
    Reminders.instance.cancel(t);
    if (t.repeat != Repeat.none) {
      final next = _nextOccurrence(t);
      tasks[next.id] = next;
      Reminders.instance.schedule(next);
    }
    var inNebula = false;
    var reborn = false;
    if (star.phase == Phase.nebula) {
      inNebula = true;
      star.progress += 1;
      if (star.progress >= rebirthNeed) {
        star
          ..phase = Phase.star
          ..progress = 0
          ..rebirths += 1
          ..armed = load <= 1;
        reborn = true;
      }
    }
    _commit();
    _events.add(TaskCompleted(t, max(1, freed), inNebula));
    if (reborn) _events.add(Rebirth());
    checkStar();
  }

  Task _nextOccurrence(Task t) {
    int step(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      switch (t.repeat) {
        case Repeat.daily:
          return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute).millisecondsSinceEpoch;
        case Repeat.weekly:
          return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute).millisecondsSinceEpoch;
        default:
          return DateTime(d.year, d.month + 1, d.day, d.hour, d.minute).millisecondsSinceEpoch;
      }
    }

    int? due;
    int showFrom;
    if (t.due != null) {
      due = step(t.due!);
      while (due! < nowMs()) {
        due = step(due);
      }
      final lead = t.repeat == Repeat.daily ? 0 : (t.repeat == Repeat.weekly ? 2 : 5);
      showFrom = startOfDay(due - lead * 86400000);
    } else {
      showFrom = startOfDay(step(nowMs()));
    }
    final n = nowMs();
    return Task(
      id: newId('t'),
      title: t.title,
      catId: t.catId,
      size: t.size,
      due: due,
      repeat: t.repeat,
      notes: t.notes,
      remind: t.remind,
      subs: t.subs.map((s) => SubTask(id: newId('s'), text: s.text)).toList(),
      createdAt: n,
      showFrom: showFrom,
      log: [LogEntry(n, 'created')],
    );
  }

  void reopen(String id) {
    final t = tasks[id];
    if (t == null) return;
    t.completedAt = null;
    t.log.add(LogEntry(nowMs(), 'reopened'));
    _commit();
    Reminders.instance.schedule(t);
    checkStar();
  }

  Task? delete(String id) {
    final t = tasks.remove(id);
    if (t != null) Reminders.instance.cancel(t);
    _commit();
    return t;
  }

  void restore(Task t) {
    tasks[t.id] = t;
    _commit();
    Reminders.instance.schedule(t);
    checkStar();
  }

  void addSub(String id, String text) {
    final t = tasks[id];
    if (t == null) return;
    t.subs.add(SubTask(id: newId('s'), text: text));
    _commit();
  }

  void toggleSub(String id, String subId) {
    final t = tasks[id];
    if (t == null) return;
    final s = t.subs.firstWhere((x) => x.id == subId);
    s.done = !s.done;
    if (s.done) t.log.add(LogEntry(nowMs(), 'sub', s.text));
    _commit();
  }

  void removeSub(String id, String subId) {
    final t = tasks[id];
    if (t == null) return;
    t.subs.removeWhere((x) => x.id == subId);
    _commit();
  }

  void setNotes(String id, String notes) {
    final t = tasks[id];
    if (t == null || t.notes == notes) return;
    t.notes = notes;
    _save();
  }

  /* ---------- categories & settings ---------- */
  bool addCat(String name, int color) {
    if (cats.values.any((c) => c.name.toLowerCase() == name.toLowerCase())) return false;
    final c = TaskType(id: newId('c'), name: name, color: color, createdAt: nowMs());
    cats[c.id] = c;
    _commit();
    return true;
  }

  void deleteCat(String id) {
    cats.remove(id);
    for (final t in tasks.values) {
      if (t.catId == id) t.catId = null;
    }
    if (lastCat == id) lastCat = null;
    _commit();
  }

  void setCap(int cap) {
    star.cap = cap;
    _commit();
    checkStar();
  }

  void setSound(bool v) {
    sound = v;
    _commit();
  }

  void setHaptics(bool v) {
    haptics = v;
    _commit();
  }
}
