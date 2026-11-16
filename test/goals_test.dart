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

  test('con una sola meta al día basta para la racha', () {
    final a = store.addGoal(title: 'correr', color: catPalette[0]);
    final b = store.addGoal(title: 'leer', color: catPalette[1]);
    a.days.addAll({_ago(1), _ago(3)});
    b.days.add(_ago(2));
    expect(store.goalStreak, 3);
    store.toggleGoalToday(b.id);
    expect(store.goalStreak, 4);
    expect(store.goalDoneToday, isTrue);
    store.toggleGoalToday(b.id); // desmarcar
    expect(store.goalDoneToday, isFalse);
    expect(store.goalStreak, 3);
  });

  test('llegar a 3 días desbloquea la primera constelación una sola vez', () async {
    final events = <StarEvent>[];
    final sub = store.events.listen(events.add);
    final g = store.addGoal(title: 'meditar', color: catPalette[0]);
    final h = store.addGoal(title: 'agua', color: catPalette[1]);
    g.days.addAll({_ago(1), _ago(2)});
    expect(store.nextReward!.name, 'Triángulo');
    store.toggleGoalToday(g.id);
    store.toggleGoalToday(h.id); // segunda meta el mismo día: no repite premio
    await Future<void>.delayed(Duration.zero);
    final checks = events.whereType<GoalChecked>().toList();
    expect(checks.first.unlocked?.name, 'Triángulo');
    expect(checks.first.streak, 3);
    expect(checks.last.unlocked, isNull);
    expect(checks.last.streak, -1);
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
    expect(again.goalStreak, 1);
  });
}
