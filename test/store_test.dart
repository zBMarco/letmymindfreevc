import 'package:flutter_test/flutter_test.dart';
import 'package:mi_estrella/models.dart';
import 'package:mi_estrella/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore();
    await store.init();
  });

  test('cada tarea suma carga según su tamaño', () {
    store.addTask(title: 'a', size: 3);
    store.addTask(title: 'b', size: 2);
    expect(store.load, closeTo(5 / 20, 1e-9));
    expect(store.level.name, 'Tranquila');
  });

  test('los pasos hechos bajan la carga y las vencidas pesan el doble', () {
    final t = store.addTask(title: 'a', size: 5);
    store.addSub(t.id, 'uno');
    store.addSub(t.id, 'dos');
    store.toggleSub(t.id, t.subs.first.id);
    expect(store.load, closeTo(5 * (1 - .6 * .5) / 20, 1e-9));
    final late = store.addTask(title: 'vencida', size: 2, due: nowMs() - 1000);
    expect(late.load, 4);
  });

  test('pasar de 100% provoca supernova y 3 tareas la hacen renacer', () async {
    final events = <StarEvent>[];
    final sub = store.events.listen(events.add);
    final ids = [for (var i = 0; i < 5; i++) store.addTask(title: 't$i', size: 5).id];
    await Future<void>.delayed(Duration.zero);
    expect(store.star.phase, Phase.nebula);
    expect(events.whereType<Supernova>().length, 1);

    store.complete(ids[0]);
    store.complete(ids[1]);
    expect(store.star.phase, Phase.nebula);
    expect(store.star.progress, 2);
    store.complete(ids[2]);
    await Future<void>.delayed(Duration.zero);
    expect(store.star.phase, Phase.star);
    expect(store.star.rebirths, 1);
    expect(events.whereType<Rebirth>().length, 1);
    await sub.cancel();
  });

  test('no vuelve a explotar justo después de renacer', () {
    final ids = [for (var i = 0; i < 6; i++) store.addTask(title: 't$i', size: 5).id];
    for (final id in ids.take(3)) {
      store.complete(id);
    }
    // 3 tareas de 5 siguen pendientes = 75%: estable, renacida, sin nueva supernova
    expect(store.star.phase, Phase.star);
    expect(store.star.supernovas, 1);
  });

  test('una tarea diaria crea la siguiente al completarse', () {
    final t = store.addTask(title: 'meditar', size: 1, repeat: Repeat.daily);
    store.complete(t.id);
    final next = store.tasks.values.where((x) => x.title == 'meditar' && x.completedAt == null).toList();
    expect(next.length, 1);
    expect(next.first.isVisible, isFalse); // aparece mañana
    expect(store.upcoming.length, 1);
  });

  test('los datos se guardan y se vuelven a cargar', () async {
    store.addCat('Casa', 0xFFFFD27A);
    store.addTask(title: 'lavar', size: 2, catId: store.sortedCats.first.id);
    final again = AppStore();
    await again.init();
    expect(again.tasks.length, 1);
    expect(again.cats.length, 1);
    expect(again.tasks.values.first.catId, again.cats.keys.first);
  });
}
