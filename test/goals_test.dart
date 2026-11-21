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

  test('la racha suma las tareas de días seguidos y sigue viva hasta que acaba el día', () {
    expect(streakOf({_ago(1): 1, _ago(2): 1, _ago(3): 1}), 3); // hoy aún no, pero sigue viva
    expect(streakOf({_ago(0): 2, _ago(1): 3, _ago(2): 1}), 6);
    expect(streakOf({_ago(0): 4, _ago(2): 5}), 4); // ayer faltó: solo cuenta lo de hoy
    expect(streakOf({_ago(2): 1, _ago(3): 1}), 0); // ayer no: se rompió
    expect(streakOf({}), 0);
    expect(bestStreakOf({_ago(0): 2, _ago(5): 1, _ago(6): 3, _ago(7): 1, _ago(8): 1}), 6);
    expect(bestStreakOf({_ago(0): 9, _ago(5): 1, _ago(6): 1}), 9);
    expect(bestStreakOf({}), 0);
  });

  test('cada tarea completada suma uno a la racha; las metas no', () {
    void doneOn(int daysAgo) {
      final t = store.addTask(title: 'tarea $daysAgo');
      final d = DateTime.now();
      t.completedAt = DateTime(d.year, d.month, d.day - daysAgo, 12).millisecondsSinceEpoch;
    }

    doneOn(1);
    doneOn(2);
    doneOn(2); // dos tareas el mismo día cuentan dos
    doneOn(3);
    expect(store.streak, 4);
    expect(store.streakToday, isFalse);
    final g = store.addGoal(title: 'correr', color: catPalette[0]);
    store.toggleGoalToday(g.id); // marcar una meta no mueve la racha
    expect(store.streak, 4);
    expect(store.streakToday, isFalse);
    final t = store.addTask(title: 'hoy');
    store.complete(t.id);
    expect(store.streak, 5);
    expect(store.streakToday, isTrue);
    store.complete(store.addTask(title: 'otra hoy').id);
    expect(store.streak, 6);
    store.reopen(t.id); // reabrirla la quita
    expect(store.streak, 5);
    doneOn(5); // hubo un hueco el día 4: esa tarea no se suma
    expect(store.streak, 5);
  });

  test('llegar a 3 tareas desbloquea la primera constelación una sola vez', () async {
    final events = <StarEvent>[];
    final sub = store.events.listen(events.add);
    final t = store.addTask(title: 'ayer');
    final d = DateTime.now();
    t.completedAt = DateTime(d.year, d.month, d.day - 1, 12).millisecondsSinceEpoch;
    expect(store.nextReward!.name, 'Triángulo');
    store.complete(store.addTask(title: 'una').id);
    store.complete(store.addTask(title: 'dos').id); // la tercera de la racha
    store.complete(store.addTask(title: 'tres').id); // no repite premio
    await Future<void>.delayed(Duration.zero);
    final done = events.whereType<TaskCompleted>().toList();
    expect(done.map((e) => e.streak), [2, 3, 4]);
    expect(done[0].unlocked, isNull);
    expect(done[1].unlocked?.name, 'Triángulo');
    expect(done[2].unlocked, isNull);
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

  test('el fuego de la racha sube de color con las tareas', () {
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
