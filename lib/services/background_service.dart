import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create notification channel first
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'snapshot_memo_background', // id
        'Background Monitoring', // title
        description: 'Used for detecting screenshots in the background',
        importance: Importance.low,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'snapshot_memo_background',
        initialNotificationTitle: 'Snapshot Memo',
        initialNotificationContent: 'Monitoring for screenshots...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    // Start it explicitly just in case autoStart fails
    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // iOS background fetch is limited
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Re-initialize notifications in this isolate
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Periodic check logic
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (!await service.isForegroundService()) {
           // If we're not in foreground but service running, we should still check
        }
      }

      await _checkForNewScreenshot(flutterLocalNotificationsPlugin);
    });
  }

  static String? _lastSeenAssetId;

  static Future<void> _checkForNewScreenshot(
      FlutterLocalNotificationsPlugin notifications) async {
    // Note: PhotoManager needs permission check again in this isolate context
    // or rely on the main app having asked for it. 
    // In background, we assume permissions are already granted.
    
    // We check purely for recent images.
    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
           imageOption: const FilterOption(
             sizeConstraint: SizeConstraint(ignoreSize: true),
           ),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (paths.isEmpty) return;

      final List<AssetEntity> entities = await paths[0].getAssetListRange(start: 0, end: 1);
      if (entities.isEmpty) return;

      final AssetEntity latest = entities[0];
      final DateTime now = DateTime.now();
      // Check if created in last 60 seconds to avoid duplicate alerts on restart
      final bool isVeryRecent = now.difference(latest.createDateTime).inSeconds.abs() < 60; 

      final prefs = await SharedPreferences.getInstance();
      _lastSeenAssetId ??= prefs.getString('last_known_screenshot_id');

      if (_lastSeenAssetId == null) {
        _lastSeenAssetId = latest.id;
        await prefs.setString('last_known_screenshot_id', latest.id);
        return;
      }

      if (_lastSeenAssetId != latest.id) {
        // New image detected!
        _lastSeenAssetId = latest.id;
        await prefs.setString('last_known_screenshot_id', latest.id);

        if (isVeryRecent && _isScreenshot(latest)) {
           // Before showing notification, check if it's already in the database (via SharedPreferences or just let UI handle it)
           // Actually, the background service isolate doesn't share the same Hive box easily if not initialized.
           // But since we want to avoid the notification if the user is ALREADY in the UI, 
           // we can use a simpler heuristic or just rely on the UI check we just added.
           
           // However, to be extra safe, let's only show if not already seen in THIS session.
           
           await notifications.show(
            latest.id.hashCode,
            'New Screenshot Captured',
            'Tap to add a voice or text note.',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'snapshot_memo_captures',
                'New Screenshot Captures',
                channelDescription: 'Alerts when a new screenshot is detected',
                importance: Importance.max,
                priority: Priority.max,
                showWhen: true,
              ),
            ),
            payload: latest.id,
          );
        }
      }
    } catch (e) {
      // PhotoManager might throw if permission not granted
      print('Background Service: Error checking screenshots: $e');
    }
  }

  static bool _isScreenshot(AssetEntity asset) {
    final String title = asset.title?.toLowerCase() ?? '';
    // Relative path is sometimes null in limited access, check title principally
    return title.contains('screenshot') || title.contains('scr_');
  }
}