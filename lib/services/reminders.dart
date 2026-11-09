import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';
import 'platform/save_file.dart';

/// Local notifications scheduled on the iPhone itself (no server needed),
/// plus "add to Calendar" through the native iOS event sheet.
class Reminders {
  Reminders._();
  static final instance = Reminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Several nudges before the deadline: 1 day, 3 h, 1 h, 30 min, and at the deadline.
  static const _offsets = [
    (Duration(days: 1), 'Mañana vence'),
    (Duration(hours: 3), 'En 3 horas vence'),
    (Duration(hours: 1), 'En 1 hora vence'),
    (Duration(minutes: 30), 'En 30 min vence'),
    (Duration.zero, 'Vence ahora'),
  ];

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Zona horaria no disponible: $e');
    }
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(settings: const InitializationSettings(iOS: darwin));
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  int _base(Task t) => (t.id.hashCode & 0x0FFFFFFF) % 200000000;

  Future<void> schedule(Task t) async {
    if (!_ready) return;
    await cancel(t);
    if (!t.remind || t.due == null || t.completedAt != null) return;
    await requestPermission();
    final due = DateTime.fromMillisecondsSinceEpoch(t.due!);
    for (var k = 0; k < _offsets.length; k++) {
      final (offset, label) = _offsets[k];
      final at = due.subtract(offset);
      if (at.isBefore(DateTime.now().add(const Duration(seconds: 5)))) continue;
      try {
        await _plugin.zonedSchedule(
          id: _base(t) * 10 + k,
          title: '$label: ${t.title}',
          body: k == _offsets.length - 1
              ? 'Si se vence, pesa el doble en tu estrella. Suéltala ya.'
              : 'Tu estrella te lo recuerda. Termínala y suelta esa carga.',
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: const NotificationDetails(
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true, presentList: true),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('No se pudo programar recordatorio: $e');
      }
    }
  }

  Future<void> cancel(Task t) async {
    if (!_ready) return;
    for (var k = 0; k < _offsets.length; k++) {
      await _plugin.cancel(id: _base(t) * 10 + k);
    }
  }

  /// Opens the native iOS "new event" sheet prefilled with the task.
  Future<bool> addToCalendar(Task t) async {
    if (t.due == null) return false;
    if (kIsWeb) return saveTextFile('estrella-${t.id}.ics', 'text/calendar', icsFor(t));
    final due = DateTime.fromMillisecondsSinceEpoch(t.due!);
    final rec = switch (t.repeat) {
      Repeat.daily => cal.Recurrence(frequency: cal.Frequency.daily),
      Repeat.weekly => cal.Recurrence(frequency: cal.Frequency.weekly),
      Repeat.monthly => cal.Recurrence(frequency: cal.Frequency.monthly),
      Repeat.none => null,
    };
    return cal.Add2Calendar.addEvent2Cal(cal.Event(
      title: '★ ${t.title}',
      description: '${t.notes.isNotEmpty ? '${t.notes}\n\n' : ''}Suelta esta carga de tu estrella.',
      startDate: due.subtract(const Duration(minutes: 30)),
      endDate: due,
      iosParams: const cal.IOSParams(reminder: Duration(hours: 1)),
      recurrence: rec,
    ));
  }

  /// Web version: an .ics event whose alarms make the iPhone Calendar do the
  /// reminding (a web page can't schedule notifications on its own).
  @visibleForTesting
  static String icsFor(Task t) {
    String stamp(DateTime d) {
      final u = d.toUtc();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
    }

    String esc(String v) => v.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\n', '\\n');
    final due = DateTime.fromMillisecondsSinceEpoch(t.due!);
    final rule = switch (t.repeat) {
      Repeat.daily => 'RRULE:FREQ=DAILY',
      Repeat.weekly => 'RRULE:FREQ=WEEKLY',
      Repeat.monthly => 'RRULE:FREQ=MONTHLY',
      Repeat.none => null,
    };
    final alarms = [
      for (final (offset, label) in _offsets)
        [
          'BEGIN:VALARM',
          'ACTION:DISPLAY',
          'DESCRIPTION:${esc('$label: ${t.title}')}',
          // Relative to the end (the deadline), so "Vence ahora" fires at the deadline.
          'TRIGGER;RELATED=END:${offset == Duration.zero ? 'PT0M' : '-P${offset.inDays > 0 ? '${offset.inDays}D' : 'T${offset.inMinutes}M'}'}',
          'END:VALARM',
        ].join('\r\n'),
    ];
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Mi Estrella//ES',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:${t.id}@mi-estrella',
      'DTSTAMP:${stamp(DateTime.now())}',
      'DTSTART:${stamp(due.subtract(const Duration(minutes: 30)))}',
      'DTEND:${stamp(due)}',
      'SUMMARY:${esc('★ ${t.title}')}',
      'DESCRIPTION:${esc('${t.notes.isNotEmpty ? '${t.notes}\n\n' : ''}Suelta esta carga de tu estrella.')}',
      ?rule,
      if (t.remind) ...alarms,
      'END:VEVENT',
      'END:VCALENDAR',
      '',
    ].join('\r\n');
  }
}
