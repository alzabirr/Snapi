import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create notification channel first
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const AndroidNotificationChannel backgroundChannel = AndroidNotificationChannel(
        'snapshot_memo_background',
        'Background Monitoring',
        description: 'Used for detecting screenshots in the background',
        importance: Importance.low,
      );

      const AndroidNotificationChannel capturesChannel = AndroidNotificationChannel(
        'snapshot_memo_captures',
        'New Screenshot Captures',
        description: 'Alerts when a new screenshot is detected',
        importance: Importance.max,
      );

      await androidImplementation?.createNotificationChannel(backgroundChannel);
      await androidImplementation?.createNotificationChannel(capturesChannel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'snapshot_memo_background',
        initialNotificationTitle: 'Snapi',
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
    
    // Initialize DB in this isolate
    try {
      await DatabaseService.init();
      // Ignore permission check in background isolate for PhotoManager
      PhotoManager.setIgnorePermissionCheck(true);
    } catch (e) {
      debugPrint('Background Service: DB Init failed: $e');
    }
    
    bool showNotifications = true;
    
    // Listen for config updates from the main app
    service.on('updateConfig').listen((event) {
      if (event != null && event['showNotifications'] != null) {
        showNotifications = event['showNotifications'];
        debugPrint('Background Service: Notifications updated to $showNotifications');
      }
    });

    // Initial load of settings
    try {
      final prefs = await SharedPreferences.getInstance();
      showNotifications = prefs.getBool('show_screenshot_notifications') ?? true;
    } catch (e) {
      debugPrint('Background Service: Failed to load initial settings: $e');
    }

    // Re-initialize notifications in this isolate (CRITICAL: must call initialize())
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Recreate notification channel in this isolate (required on some devices)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      const AndroidNotificationChannel capturesChannel = AndroidNotificationChannel(
        'snapshot_memo_captures',
        'New Screenshot Captures',
        description: 'Alerts when a new screenshot is detected',
        importance: Importance.max,
      );
      await androidPlugin?.createNotificationChannel(capturesChannel);
    }

    // Periodic check logic (Optimized for 24/7 stability)
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _checkForNewScreenshot(flutterLocalNotificationsPlugin, showNotifications);
    });
  }

  static String? _lastSeenAssetId;

  static Future<void> _checkForNewScreenshot(
      FlutterLocalNotificationsPlugin notifications, bool showNotifications) async {
    // Note: PhotoManager needs permission check again in this isolate context
    // or rely on the main app having asked for it. 
    // In background, we assume permissions are already granted.
    
    // We check purely for recent images.
    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true, // Optimized for speed
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

      final List<AssetEntity> entities = await paths[0].getAssetListRange(start: 0, end: 5);
      if (entities.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      _lastSeenAssetId ??= prefs.getString('last_known_screenshot_id');

      // First run — just set baseline, don't notify
      if (_lastSeenAssetId == null) {
        _lastSeenAssetId = entities[0].id;
        await prefs.setString('last_known_screenshot_id', entities[0].id);
        return;
      }

      // Loop through recent assets until we hit one we've already seen
      for (final asset in entities) {
        if (asset.id == _lastSeenAssetId) break; // Already handled

        final DateTime now = DateTime.now();
        final bool isVeryRecent = now.difference(asset.createDateTime).inSeconds.abs() < 60;

        if (isVeryRecent && _isScreenshot(asset) && showNotifications) {
          // Check if already saved in database
          final items = DatabaseService.getAllItems();
          final alreadyInDb = items.any((item) => item.id == asset.id);
          
          if (alreadyInDb) {
            debugPrint('Background Service: Screenshot ${asset.id} already in DB. Skipping.');
            continue;
          }

          await notifications.show(
            asset.id.hashCode,
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
            payload: asset.id,
          );
        }
      }

      // Update baseline to newest asset
      _lastSeenAssetId = entities[0].id;
      await prefs.setString('last_known_screenshot_id', _lastSeenAssetId!);
    } catch (e) {
      // PhotoManager might throw if permission not granted
      print('Background Service: Error checking screenshots: $e');
    }
  }

  static bool _isScreenshot(AssetEntity asset) {
    final String title = asset.title?.toLowerCase() ?? '';
    final String path = asset.relativePath?.toLowerCase() ?? '';
    
    // Check title (filename)
    final bool matchesTitle = title.contains('screenshot') || 
                              title.contains('scr_') || 
                              title.contains('screencap') ||
                              title.contains('screengrab') ||
                              title.contains('screencapture') ||
                              title.contains('screen-shot') ||
                              title.contains('screen_shot') ||
                              title.contains('screen shot') ||
                              title.contains('capture');

    // Check path (folder)
    final bool matchesPath = path.contains('screenshot') || 
                             path.contains('screencap') ||
                             path.contains('capture') ||
                             path.contains('screencapture') ||
                             path.contains('screen-shot') ||
                             path.contains('screen_shot');
                             
    return matchesTitle || matchesPath;
  }
}