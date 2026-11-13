import 'package:flutter_test/flutter_test.dart';
import 'package:mi_estrella/models.dart';
import 'package:mi_estrella/star/solar_system.dart';
import 'package:mi_estrella/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore();
    await store.init();
  });

  test('cada tipo es un planeta y sus subtareas pendientes son lunas', () {
    store.addCat('Trabajo', 0xFF7CC8FF);
    store.addCat('Casa', 0xFFFFD27A);
    final work = store.sortedCats.first.id;
    final t = store.addTask(title: 'reporte', catId: work, size: 3);
    store.addSub(t.id, 'uno');
    store.addSub(t.id, 'dos');
    store.addSub(t.id, 'tres');
    store.toggleSub(t.id, t.subs.first.id);

    final scene = SolarScene.of(store);
    expect(scene.planets.map((p) => p.name), ['Trabajo', 'Casa']);
    expect(scene.planets.first.moons, 2);
    expect(scene.planets.first.load, closeTo(t.load, 1e-9));
    expect(scene.planets.last.load, 0);
  });

  test('la fecha límite acerca la órbita: vencida = máxima urgencia', () {
    store.addCat('Trámites', 0xFFFF9F7A);
    store.addCat('Casa', 0xFFFFD27A);
    final c = store.sortedCats;
    store.addTask(title: 'vencida', catId: c[0].id, due: nowMs() - 1000);
    store.addTask(title: 'lejana', catId: c[1].id, due: nowMs() + 30 * 86400000);
    final scene = SolarScene.of(store);
    expect(scene.planets[0].urgency, 1);
    expect(scene.planets[1].urgency, 0);
    expect(dueLabel(scene.planets[0].nextDue), 'vencida');
  });

  test('las tareas terminadas son rocas del cinturón y las sin tipo forman su planeta', () {
    for (var i = 0; i < 5; i++) {
      store.complete(store.addTask(title: 'h$i', size: 2).id);
    }
    store.addTask(title: 'suelta', size: 1);
    final scene = SolarScene.of(store);
    expect(scene.belt.length, 5);
    expect(scene.belt.every((r) => r.fresh), isTrue);
    expect(scene.planets.single.id, noTypeId);
  });

  test('el aspecto de cada planeta es estable', () {
    expect(hash01('c-abc'), hash01('c-abc'));
    expect(hash01('c-abc'), isNot(hash01('c-abd')));
    for (final s in ['a', 'bb', 'ccc', 'tipo-123']) {
      expect(hash01(s), inInclusiveRange(0, 1));
    }
  });
}
