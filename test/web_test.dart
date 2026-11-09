import 'package:flutter_test/flutter_test.dart';
import 'package:mi_estrella/models.dart';
import 'package:mi_estrella/services/reminders.dart';
import 'package:mi_estrella/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('el evento .ics lleva los 5 avisos antes de la fecha límite', () async {
    final store = AppStore();
    await store.init();
    final due = DateTime.utc(2026, 12, 1, 18).millisecondsSinceEpoch;
    final t = store.addTask(title: 'Pagar; la tarjeta, ya', size: 2, due: due, remind: true, repeat: Repeat.weekly);
    final ics = Reminders.icsFor(t);
    expect(ics, contains('DTEND:20261201T180000Z'));
    expect(ics, contains(r'SUMMARY:★ Pagar\; la tarjeta\, ya'));
    expect(ics, contains('RRULE:FREQ=WEEKLY'));
    for (final trig in ['-P1D', '-PT180M', '-PT60M', '-PT30M', 'PT0M']) {
      expect(ics, contains('TRIGGER;RELATED=END:$trig'));
    }
    expect('BEGIN:VALARM'.allMatches(ics).length, 5);
  });

  test('un respaldo se restaura completo y un archivo cualquiera no borra nada', () async {
    final a = AppStore();
    await a.init();
    a.addCat('Casa', 0xFFFFD27A);
    final t = a.addTask(title: 'lavar', size: 3, catId: a.sortedCats.first.id);
    a.complete(t.id);
    a.addTask(title: 'barrer', size: 1);
    final backup = a.exportBackup();

    SharedPreferences.setMockInitialValues({});
    final b = AppStore();
    await b.init();
    b.addTask(title: 'se va a reemplazar', size: 1);
    expect(b.importBackup('hola'), isFalse);
    expect(b.tasks.length, 1);
    expect(b.importBackup(backup), isTrue);
    expect(b.tasks.values.map((x) => x.title).toSet(), {'lavar', 'barrer'});
    expect(b.cats.length, 1);
    expect(b.doneToday.length, 1);
  });
}
