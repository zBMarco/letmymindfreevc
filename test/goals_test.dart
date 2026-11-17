import 'package:flutter_test/flutter_test.dart';
import 'package:mi_estrella/models.dart';
import 'package:mi_estrella/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _ago(int n) {
  final d = DateTime.now();
  return dayKey(DateTime(d.year, d.month, d.day - n, 12).millisecondsSinceEpoch);
}

void main() {
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore();
    await store.init();
  });

  test('la racha cuenta días seguidos y sigue viva hasta que acaba el día', () {
    expect(streakOf({_ago(1), _ago(2), _ago(3)}), 3); // hoy aún no, pero sigue viva
    expect(streakOf({_ago(0), _ago(1), _ago(2)}), 3);
    expect(streakOf({_ago(0), _ago(2)}), 1);
    expect(streakOf({_ago(2), _ago(3)}), 0); // ayer no: se rompió
    expect(bestStreakOf({_ago(0), _ago(5), _ago(6), _ago(7), _ago(8)}), 4);
  });

  test('la racha cuenta los días con al menos una tarea completada, no las metas', () {
    void doneOn(int daysAgo) {
      final t = store.addTask(title: 'tarea $daysAgo');
      final d = DateTime.now();
      t.completedAt = DateTime(d.year, d.month, d.day - daysAgo, 12).millisecondsSinceEpoch;
    }

    doneOn(1);
    doneOn(2);
    doneOn(2); // dos tareas el mismo día cuentan una vez
    doneOn(3);
    expect(store.streak, 3);
    expect(store.streakToday, isFalse);
    final g = store.addGoal(title: 'correr', color: catPalette[0]);
    store.toggleGoalToday(g.id); // marcar una meta no mueve la racha
    expect(store.streak, 3);
    expect(store.streakToday, isFalse);
    final t = store.addTask(title: 'hoy');
    store.complete(t.id);
    expect(store.streak, 4);
    expect(store.streakToday, isTrue);
    store.reopen(t.id); // reabrirla la quita
    expect(store.streak, 3);
  });

  test('llegar a 3 días desbloquea la primera constelación una sola vez', () async {
    final events = <StarEvent>[];
    final sub = store.events.listen(events.add);
    for (final n in [1, 2]) {
      final t = store.addTask(title: 'antes $n');
      final d = DateTime.now();
      t.completedAt = DateTime(d.year, d.month, d.day - n, 12).millisecondsSinceEpoch;
    }
    expect(store.nextReward!.name, 'Triángulo');
    store.complete(store.addTask(title: 'una').id);
    store.complete(store.addTask(title: 'otra').id); // segunda tarea el mismo día: no repite premio
    await Future<void>.delayed(Duration.zero);
    final done = events.whereType<TaskCompleted>().toList();
    expect(done.first.unlocked?.name, 'Triángulo');
    expect(done.first.streak, 3);
    expect(done.last.unlocked, isNull);
    expect(done.last.streak, -1);
    expect(store.unlockedRewards.length, 1);
    expect(store.nextReward!.name, 'Casiopea');
    await sub.cancel();
  });

  test('las metas logradas y sus días se guardan', () async {
    final g = store.addGoal(title: 'inglés', why: 'para viajar', color: catPalette[2], target: nowMs() + 86400000);
    store.toggleGoalToday(g.id);
    store.achieveGoal(g.id);
    final again = AppStore();
    await again.init();
    final r = again.goals.values.single;
    expect(r.why, 'para viajar');
    expect(r.active, isFalse);
    expect(r.doneToday, isTrue);
    expect(again.goalDoneToday, isTrue);
  });

  test('el fuego de la racha sube de color con los días', () {
    String name(int d) => flameTiers[flameTierOf(d)].name;
    expect(name(0), 'Apagado');
    expect(name(1), 'Brasa');
    expect(name(2), 'Brasa');
    expect(name(3), 'Fuego naranja');
    expect(name(7), 'Fuego amarillo');
    expect(name(14), 'Fuego blanco');
    expect(name(29), 'Fuego blanco');
    expect(name(30), 'Fuego azul');
    expect(name(100), 'Fuego violeta');
    expect(name(400), 'Fuego estelar');
  });
}
