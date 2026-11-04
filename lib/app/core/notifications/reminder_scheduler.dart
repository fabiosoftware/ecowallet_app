import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

abstract class ReminderScheduler {
  Future<void> init();

  /// Agenda os próximos lembretes diários. Se [registeredToday] for true, o
  /// lembrete de hoje é pulado.
  Future<void> reschedule({required bool registeredToday});
}

class NoopReminderScheduler implements ReminderScheduler {
  @override
  Future<void> init() async {}

  @override
  Future<void> reschedule({required bool registeredToday}) async {}
}

class LocalReminderScheduler implements ReminderScheduler {
  static const int _hour = 20;
  static const int _daysAhead = 7;
  static const int _baseId = 1000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    // O Brasil não tem horário de verão desde 2019, então este fuso é estável.
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    _ready = true;
  }

  @override
  Future<void> reschedule({required bool registeredToday}) async {
    if (!_ready) return;

    for (var i = 0; i < _daysAhead; i++) {
      await _plugin.cancel(_baseId + i);
    }

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < _daysAhead; i++) {
      final target =
          tz.TZDateTime(tz.local, now.year, now.month, now.day + i, _hour);
      if (!target.isAfter(now)) continue;
      if (i == 0 && registeredToday) continue;

      await _plugin.zonedSchedule(
        _baseId + i,
        'EcoWallet',
        'Teve gastos hoje que você não registrou?',
        target,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Lembrete diário',
            channelDescription: 'Um lembrete por dia para registrar gastos',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
