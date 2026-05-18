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
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('is_monitoring_enabled') ?? true;

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
        initialNotificationContent: 'Snapi is monitoring',
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
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('is_monitoring_enabled') ?? true;
    
    // Initialize notifications early for both starting and stopping
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    if (!isEnabled) {
      if (service is AndroidServiceInstance) {
        service.setAsBackgroundService();
      }
      await flutterLocalNotificationsPlugin.cancel(888);
    } else {
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
        service.setForegroundNotificationInfo(
          title: 'Snapi',
          content: 'Snapi is monitoring',
        );
      }
    }
    
    // Initialize DB in this isolate
    try {
      await DatabaseService.init();
      PhotoManager.setIgnorePermissionCheck(true);
    } catch (e) {
      debugPrint('Background Service: DB Init failed: $e');
    }
    
    bool showNotifications = prefs.getBool('show_screenshot_notifications') ?? true;
    Timer? backgroundTimer;
    
    service.on('updateConfig').listen((event) async {
      if (event != null) {
        if (event['showNotifications'] != null) {
          showNotifications = event['showNotifications'];
        }
        if (event['is_monitoring_enabled'] != null) {
          final isEnabled = event['is_monitoring_enabled'];
          if (!isEnabled) {
            if (service is AndroidServiceInstance) {
              service.setAsBackgroundService();
            }
            await flutterLocalNotificationsPlugin.cancel(888);
          } else {
            if (service is AndroidServiceInstance) {
              service.setAsForegroundService();
              service.setForegroundNotificationInfo(
                title: 'Snapi',
                content: 'Snapi is monitoring',
              );
            }
          }
        }
      }
    });

    service.on('stopService').listen((event) async {
      backgroundTimer?.cancel();
      if (service is AndroidServiceInstance) {
        service.setAsBackgroundService(); // This demotes the service and removes the foreground notification
      }
      await flutterLocalNotificationsPlugin.cancel(888);
      service.stopSelf();
    });

    // Force the foreground service notification to be ongoing and non-swipeable
    try {
      await flutterLocalNotificationsPlugin.show(
        888, // Must match foregroundServiceNotificationId
        'Snapi',
        'Snapi is monitoring',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'snapshot_memo_background',
            'Background Monitoring',
            channelDescription: 'Used for detecting screenshots in the background',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Background Service: Failed to show persistent notification: $e');
    }

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
    backgroundTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // Fallback check: if event channel is broken, read from SharedPreferences directly
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final isEnabled = prefs.getBool('is_monitoring_enabled') ?? true;
        if (!isEnabled) {
          if (service is AndroidServiceInstance) {
            service.setAsBackgroundService();
          }
          await flutterLocalNotificationsPlugin.cancel(888);
        } else {
          if (service is AndroidServiceInstance) {
            service.setAsForegroundService();
          }
          // Re-show/refresh the persistent notification to ensure it's never gone
          try {
            await flutterLocalNotificationsPlugin.show(
              888, // Must match foregroundServiceNotificationId
              'Snapi',
              'Snapi is monitoring',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'snapshot_memo_background',
                  'Background Monitoring',
                  channelDescription: 'Used for detecting screenshots in the background',
                  importance: Importance.low,
                  priority: Priority.low,
                  ongoing: true,
                  autoCancel: false,
                  onlyAlertOnce: true,
                  showWhen: false,
                ),
              ),
            );
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Fallback check error: $e');
      }

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
        final bool isVeryRecent = now.difference(asset.createDateTime).inSeconds.abs() < 300;

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