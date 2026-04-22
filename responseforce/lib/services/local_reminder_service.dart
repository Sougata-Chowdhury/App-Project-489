import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ReminderPermissionStatus {
  const ReminderPermissionStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsEnabled;

  bool get allGranted => notificationsEnabled && exactAlarmsEnabled;
  bool get canScheduleReminders => notificationsEnabled;
}

class LocalReminderService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    final location = tz.timeZoneDatabase.locations[timezoneName];
    if (location == null) {
      throw StateError('Unsupported local timezone: $timezoneName');
    }
    tz.setLocalLocation(location);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _isInitialized = true;
  }

  Future<ReminderPermissionStatus> getPermissionStatus() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      final notificationsEnabled =
          await androidImpl.areNotificationsEnabled() ?? false;
      final exactAlarmsEnabled =
          await androidImpl.canScheduleExactNotifications() ?? false;
      return ReminderPermissionStatus(
        notificationsEnabled: notificationsEnabled,
        exactAlarmsEnabled: exactAlarmsEnabled,
      );
    }

    return const ReminderPermissionStatus(
      notificationsEnabled: true,
      exactAlarmsEnabled: true,
    );
  }

  Future<ReminderPermissionStatus> requestPermissions() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    return getPermissionStatus();
  }

  Future<ReminderPermissionStatus> ensureSchedulingPermissions() async {
    final current = await getPermissionStatus();
    if (current.canScheduleReminders) return current;

    final requested = await requestPermissions();
    if (requested.canScheduleReminders) return requested;

    throw StateError('Enable Notifications permission to schedule reminders.');
  }

  Future<void> replaceRoutineReminders({
    required String routineId,
    required String medicineName,
    String? dosage,
    required List<String> reminderTimes,
    required bool isActive,
    List<String> oldReminderTimes = const [],
  }) async {
    if (!_isInitialized) {
      throw StateError('LocalReminderService is not initialized.');
    }

    final allTimes = <String>{...oldReminderTimes, ...reminderTimes};
    for (final time in allTimes) {
      await _plugin.cancel(_notificationId(routineId, time));
    }

    if (!isActive) return;
    final permissionStatus = await ensureSchedulingPermissions();
    final scheduleMode = permissionStatus.exactAlarmsEnabled
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    for (final time in reminderTimes) {
      final parsed = _parseTime(time);
      if (parsed == null) continue;

      final scheduled = _nextInstanceOfTime(parsed.hour, parsed.minute);
      await _plugin.zonedSchedule(
        _notificationId(routineId, time),
        'Medicine reminder',
        dosage != null && dosage.trim().isNotEmpty
            ? 'Time to take $medicineName ($dosage).'
            : 'Time to take $medicineName.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Daily medicine reminders for elders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'medication|$routineId|$time',
      );
    }
  }

  Future<void> cancelRoutineReminders({
    required String routineId,
    required List<String> reminderTimes,
  }) async {
    for (final time in reminderTimes) {
      await _plugin.cancel(_notificationId(routineId, time));
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      _stableHash(
        'instant|${DateTime.now().millisecondsSinceEpoch}|$title|$body',
      ),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_reminders',
          'Medication Reminders',
          channelDescription: 'Daily medicine reminders for elders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      // If user selects the current minute, trigger shortly instead of waiting a full day.
      if (now.hour == hour && now.minute == minute) {
        return now.add(const Duration(seconds: 10));
      }
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _notificationId(String routineId, String time) {
    return _stableHash('medication|$routineId|$time');
  }

  int _stableHash(String input) {
    var hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
