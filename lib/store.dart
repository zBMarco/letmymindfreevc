import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services/reminders.dart';

/// Things that happened that the UI turns into light and haptics.
sealed class StarEvent {}

class TaskCompleted extends StarEvent {
  final Task task;
  final int pctFreed;
  final bool inNebula;

  /// The streak right after this task (every completed task adds one).
  final int streak;

  /// Set when this completion reached a constellation for the first time.
  final Reward? unlocked;
  TaskCompleted(this.task, this.pctFreed, this.inNebula, {this.streak = 0, this.unlocked});
}

class Supernova extends StarEvent {}

class Rebirth extends StarEvent {}

class GoalChecked extends StarEvent {
  final Goal goal;

  /// True when this is the first goal kept today.
  final bool firstToday;
  GoalChecked(this.goal, this.firstToday);
}

class GoalAchieved extends StarEvent {
  final Goal goal;
  GoalAchieved(this.goal);
}

class AppStore extends ChangeNotifier {
  static const _key = 'miestrella.v1';
  final Map<String, Task> tasks = {};
  final Map<String, TaskType> cats = {};
  final Map<String, Goal> goals = {};
  StarState star = StarState();
  bool haptics = true;
  String? lastCat;

  /// When the last backup was saved, and until when the "save a backup" nudge stays quiet.
  int? lastBackup;
  int? backupSnoozeUntil;

  final _events = StreamController<StarEvent>.broadcast();
  Stream<StarEvent> get events => _events.stream;

  SharedPreferences? _prefs;
  Timer? _minute;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        _apply(jsonDecode(raw) as Map<String, dynamic>);
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

  void _apply(Map<String, dynamic> j) {
    final newTasks = <String, Task>{};
    final newCats = <String, TaskType>{};
    for (final t in (j['tasks'] as List? ?? [])) {
      final task = Task.fromJson(Map<String, dynamic>.from(t));
      newTasks[task.id] = task;
    }
    for (final c in (j['cats'] as List? ?? [])) {
      final cat = TaskType.fromJson(Map<String, dynamic>.from(c));
      newCats[cat.id] = cat;
    }
    final newGoals = <String, Goal>{};
    for (final g in (j['goals'] as List? ?? [])) {
      final goal = Goal.fromJson(Map<String, dynamic>.from(g));
      newGoals[goal.id] = goal;
    }
    final newStar = j['star'] != null ? StarState.fromJson(Map<String, dynamic>.from(j['star'])) : StarState();
    // Only replace once everything parsed, so a bad file never leaves half the data.
    tasks
      ..clear()
      ..addAll(newTasks);
    cats
      ..clear()
      ..addAll(newCats);
    goals
      ..clear()
      ..addAll(newGoals);
    star = newStar;
    haptics = j['haptics'] as bool? ?? true;
    lastCat = j['lastCat'] as String?;
    lastBackup = j['lastBackup'] as int?;
    backupSnoozeUntil = j['backupSnoozeUntil'] as int?;
  }

  Map<String, dynamic> _snapshot() => {
        'app': 'mi_estrella',
        'version': 1,
        'tasks': tasks.values.map((t) => t.toJson()).toList(),
        'cats': cats.values.map((c) => c.toJson()).toList(),
        'goals': goals.values.map((g) => g.toJson()).toList(),
        'star': star.toJson(),
        'haptics': haptics,
        'lastCat': lastCat,
        'lastBackup': lastBackup,
        'backupSnoozeUntil': backupSnoozeUntil,
      };

  void _save() => _prefs?.setString(_key, jsonEncode(_snapshot()));

  /// Full backup as text, to keep in Files/iCloud.
  String exportBackup() => const JsonEncoder.withIndent(' ').convert(_snapshot());

  /// Replaces everything with a backup. Returns false (and changes nothing) if the text isn't one.
  bool importBackup(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map<String, dynamic> || j['tasks'] is! List) return false;
      _apply(j);
    } catch (e) {
      debugPrint('Respaldo inválido: $e');
      return false;
    }
    _commit();
    return true;
  }

  static const _day = 86400000;

  /// True when it's time to remind you to save a backup: a week since the last one,
  /// or 3 days of use without ever saving one.
  bool get needsBackup {
    final n = nowMs();
    if (backupSnoozeUntil != null && n < backupSnoozeUntil!) return false;
    if (lastBackup != null) return n - lastBackup! > 7 * _day;
    final since = [...tasks.values.map((t) => t.createdAt), ...goals.values.map((g) => g.createdAt)];
    return since.isNotEmpty && n - since.reduce(min) > 3 * _day;
  }

  void markBackedUp() {
    lastBackup = nowMs();
    backupSnoozeUntil = null;
    _commit();
  }

  void snoozeBackup() {
    backupSnoozeUntil = nowMs() + 3 * _day;
    _commit();
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

  /* ---------- streak ---------- */
  /// Fake tasks done today for the ?streak= preview (web only, never saved).
  int debugStreakTasks = 0;

  /// Tasks completed on each day (by dayKey). The streak adds them up while the days are consecutive.
  Map<String, int> get streakDays {
    final m = <String, int>{};
    for (final t in done) {
      final k = dayKey(t.completedAt!);
      m[k] = (m[k] ?? 0) + 1;
    }
    if (debugStreakTasks > 0) m.update(dayKey(nowMs()), (v) => v + debugStreakTasks, ifAbsent: () => debugStreakTasks);
    return m;
  }

  /// One point per completed task; it resets when a whole day goes by without one.
  int get streak => streakOf(streakDays);
  int get bestStreak => bestStreakOf(streakDays);
  bool get streakToday => streakDays.containsKey(dayKey(nowMs()));

  /// Constellations earned (by your best streak ever, so they're never lost).
  List<Reward> get unlockedRewards {
    final best = bestStreak;
    return rewards.where((r) => r.tasks <= best).toList();
  }

  /// The constellation your current streak is drawing (null once you have them all).
  Reward? get nextReward {
    final cur = streak;
    for (final r in rewards) {
      if (r.tasks > cur) return r;
    }
    return null;
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
    final bestBefore = bestStreak;
    final n = nowMs();
    if (t.runningSince != null) t.activeMs += n - t.runningSince!;
    t.runningSince = null;
    t.completedAt = n;
    t.log.add(LogEntry(n, 'done'));
    Reminders.instance.cancel(t);
    if (t.repeat != Repeat.none) {
      final next = _nextOccurrence(t);
      tasks[next.id] = next;
      t.nextId = next.id;
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
    final st = streak;
    Reward? unlocked;
    for (final r in rewards) {
      if (r.tasks > bestBefore && r.tasks <= st) unlocked = r;
    }
    _events.add(TaskCompleted(t, max(1, freed), inNebula, streak: st, unlocked: unlocked));
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
    if (t == null || t.completedAt == null) return;
    // A repeating task already spawned its next occurrence; reopening takes it back.
    final next = t.nextId == null ? null : tasks[t.nextId];
    if (next != null && next.completedAt == null) {
      tasks.remove(next.id);
      Reminders.instance.cancel(next);
    }
    t.nextId = null;
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

  /* ---------- goals ---------- */
  List<Goal> get activeGoals => goals.values.where((g) => g.active).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  List<Goal> get achievedGoals => goals.values.where((g) => !g.active).toList()..sort((a, b) => b.achievedAt!.compareTo(a.achievedAt!));

  /// True when you already kept at least one goal today (drives the dot on the Goals tab).
  bool get goalDoneToday => goals.values.any((g) => g.days.contains(dayKey(nowMs())));

  Goal addGoal({required String title, String why = '', required int color, int? target}) {
    final g = Goal(id: newId('g'), title: title, why: why, color: color, target: target, createdAt: nowMs());
    goals[g.id] = g;
    _commit();
    return g;
  }

  void updateGoal(String id, {required String title, required String why, required int color, int? target}) {
    final g = goals[id];
    if (g == null) return;
    g
      ..title = title
      ..why = why
      ..color = color
      ..target = target;
    _commit();
  }

  /// Marks (or unmarks) today for a goal. Returns true when it ended up marked.
  bool toggleGoalToday(String id) {
    final g = goals[id];
    if (g == null || !g.active) return false;
    final today = dayKey(nowMs());
    if (g.days.remove(today)) {
      _commit();
      return false;
    }
    final firstToday = !goalDoneToday;
    g.days.add(today);
    _commit();
    _events.add(GoalChecked(g, firstToday));
    return true;
  }

  void achieveGoal(String id) {
    final g = goals[id];
    if (g == null || !g.active) return;
    g.achievedAt = nowMs();
    _commit();
    _events.add(GoalAchieved(g));
  }

  void reopenGoal(String id) {
    final g = goals[id];
    if (g == null) return;
    g.achievedAt = null;
    _commit();
  }

  Goal? deleteGoal(String id) {
    final g = goals.remove(id);
    _commit();
    return g;
  }

  void restoreGoal(Goal g) {
    goals[g.id] = g;
    _commit();
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

  void setHaptics(bool v) {
    haptics = v;
    _commit();
  }
}
