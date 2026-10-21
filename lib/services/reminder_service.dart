import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/note.dart';
import '../theme/app_theme.dart';

/// Schedules system notifications for note reminders (Android and iOS).
/// Every method is a no-op until [init] succeeds, e.g. in tests.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Note id from a reminder that launched the app, consumed once.
  String? launchNoteId;

  /// Note id from a reminder tapped while the app was running.
  final tappedNoteId = ValueNotifier<String?>(null);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'note_reminders',
      'Note reminders',
      channelDescription: 'Reminders you set on site notes',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.red,
      // Hide note contents on a locked screen.
      visibility: NotificationVisibility.private,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // Scheduling uses absolute instants, so UTC still fires on time.
      debugPrint('Timezone lookup failed, using UTC: $e');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_sitekit'),
        // Ask for permission when the user first sets a reminder instead.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => tappedNoteId.value = r.payload,
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      launchNoteId = launch!.notificationResponse?.payload;
    }
    _ready = true;
  }

  /// Asks for notification permission; returns whether it was granted.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  /// Schedules (or reschedules) the reminder for [note], if it has one in
  /// the future; otherwise cancels any pending one.
  Future<void> sync(Note note) async {
    if (!_ready) return;
    await _plugin.cancel(id: note.notificationId);
    if (!note.hasUpcomingReminder) return;

    // Exact timing needs the alarm permission on Android 12+; without it
    // the system may deliver a few minutes late.
    final exact =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        true;

    await _plugin.zonedSchedule(
      id: note.notificationId,
      title: 'Reminder: ${note.title}',
      body: note.project.isNotEmpty ? note.project : 'Tap to open your note',
      scheduledDate: tz.TZDateTime.from(note.reminderAt!, tz.local),
      notificationDetails: _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: note.id,
    );
  }

  Future<void> cancel(Note note) async {
    if (!_ready) return;
    await _plugin.cancel(id: note.notificationId);
  }
}
