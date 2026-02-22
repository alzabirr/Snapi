import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    // Configure local timezone
    try {
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      debugPrint('NotificationService: Detected Timezone = $timeZoneName');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('NotificationService: Could not get local timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        if (details.payload != null) {
          _notificationStreamController.add(details.payload!);
        }
      },
    );

    // Check if app was launched via notification
    final NotificationAppLaunchDetails? launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      if (launchDetails?.notificationResponse?.payload != null) {
        // Delay slightly to ensure listeners are ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _notificationStreamController.add(launchDetails!.notificationResponse!.payload!);
        });
      }
    }
  }

  static Future<bool> requestPermission() async {
    // Request notification permission via the plugin (handles Android 13+)
    final status = await _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    
    // Also explicitly request critical permissions using permission_handler
    if (await Permission.scheduleExactAlarm.status.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    
    return status ?? false;
  }

  // Permission shortcut
  static Future<bool> isPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  static final StreamController<String> _notificationStreamController = 
      StreamController<String>.broadcast();
  static Stream<String> get notificationStream => _notificationStreamController.stream;

  static Future<void> showCaptureNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'snapshot_memo_captures',
          'New Screenshot Captures',
          channelDescription: 'Alerts when a new screenshot is detected',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    debugPrint('NotificationService: Scheduling reminder id=$id for $scheduledDate');
    
    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
    debugPrint('NotificationService: Converted to TZ time: $tzDateTime in ${tz.local}');

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'snapshot_memo_reminders_v2',
            'Screenshot Reminders',
            channelDescription: 'Notifications for screenshot notes',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock, // Try most reliable first
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('NotificationService: Scheduled successfully using alarmClock');
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule exact alarm: $e');
      debugPrint('NotificationService: Falling back to inexact timing...');
      
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'snapshot_memo_reminders_v2',
              'Screenshot Reminders',
              channelDescription: 'Notifications for screenshot notes',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // Fallback
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        debugPrint('NotificationService: Scheduled successfully using inexact fallback');
      } catch (e2) {
        debugPrint('NotificationService: CRITICAL FAILURE to schedule reminder: $e2');
      }
    }
  }

  static Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
