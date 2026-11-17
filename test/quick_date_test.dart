import 'package:flutter_test/flutter_test.dart';
import 'package:mi_estrella/quick_date.dart';

void main() {
  // Monday 17 Nov 2025, 09:30
  final now = DateTime(2025, 11, 17, 9, 30);
  QuickDate p(String s) => parseQuickDate(s, now)!;

  test('mañana con hora am/pm', () {
    final q = p('pagar la luz mañana 5pm');
    expect(q.title, 'pagar la luz');
    expect(q.due, DateTime(2025, 11, 18, 17));
    expect(q.matched, 'mañana 5pm');
  });

  test('día de la semana con "a las" (sin am/pm, por la tarde)', () {
    final q = p('dentista el viernes a las 4');
    expect(q.title, 'dentista');
    expect(q.due, DateTime(2025, 11, 21, 16));
  });

  test('el mismo día de la semana es la próxima semana', () {
    expect(p('junta el lunes').due, DateTime(2025, 11, 24, 10));
  });

  test('fecha con mes escrito y conector colgado', () {
    final q = p('entregar reporte para el 15 de diciembre a las 10:30');
    expect(q.title, 'entregar reporte');
    expect(q.due, DateTime(2025, 12, 15, 10, 30));
  });

  test('una fecha que ya pasó este año es del siguiente', () {
    expect(p('renovar seguro 3 feb').due, DateTime(2026, 2, 3, 10));
    expect(p('renovar 2/3').due, DateTime(2026, 3, 2, 10));
  });

  test('relativas', () {
    expect(p('llamar al banco en 2 horas').due, DateTime(2025, 11, 17, 11, 30));
    expect(p('revisar en tres días').due, DateTime(2025, 11, 20, 10));
    expect(p('cita la próxima semana').due, DateTime(2025, 11, 24, 10));
  });

  test('solo hora: hoy, o mañana si ya pasó', () {
    expect(p('comprar pan 18:00').due, DateTime(2025, 11, 17, 18));
    expect(p('correr 7am').due, DateTime(2025, 11, 18, 7));
  });

  test('hoy sin hora nunca queda vencida', () {
    final late = DateTime(2025, 11, 17, 21);
    expect(parseQuickDate('lavar ropa hoy', late)!.due, DateTime(2025, 11, 17, 23, 59));
    expect(p('lavar ropa hoy').due, DateTime(2025, 11, 17, 10));
  });

  test('partes del día', () {
    expect(p('gimnasio mañana en la noche').due, DateTime(2025, 11, 18, 20));
    expect(p('llamar a mamá el sábado a las 8 de la noche').due, DateTime(2025, 11, 22, 20));
    expect(p('ir al mercado pasado mañana al mediodía').due, DateTime(2025, 11, 19, 12));
  });

  test('no inventa fechas', () {
    expect(parseQuickDate('comprar 3 kilos de manzanas', now), isNull);
    expect(parseQuickDate('leer el capítulo 12', now), isNull);
    expect(parseQuickDate('hoyo en la pared', now), isNull);
    expect(parseQuickDate('pagar 31/2', now), isNull);
  });

  test('describe la fecha', () {
    expect(describeDue(DateTime(2025, 11, 18, 17), now), 'mañana 17:00');
    expect(describeDue(DateTime(2025, 12, 15, 10, 30), now), '15 dic 10:30');
  });
}
