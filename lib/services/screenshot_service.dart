import 'dart:async';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenshotService {
  static String? _lastImageId;
  static const String _prefLastId = 'last_handled_screenshot_id';
  static final StreamController<AssetEntity> _screenshotStream = StreamController<AssetEntity>.broadcast();
  static Timer? _fallbackTimer;

  static Stream<AssetEntity> get screenshotStream => _screenshotStream.stream;

  static Future<void> startMonitoring() async {
    // Check permission first
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && ps != PermissionState.limited) {
      print('DEBUG: Screenshot monitoring failed - Permission denied: $ps');
      return;
    }
    print('DEBUG: Screenshot monitoring starting with permission: $ps');

    // Load last handled ID from storage
    final prefs = await SharedPreferences.getInstance();
    _lastImageId = prefs.getString(_prefLastId);

    // Initial check to set baseline
    await _checkForNewScreenshot(isInitial: true);

    // Use PhotoManager change notification (Instant, Event-Driven)
    PhotoManager.addChangeCallback(_onGalleryChanged);
    PhotoManager.startChangeNotify();

    // Safe fallback heartbeat (every 15s instead of 1s to save CPU)
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkForNewScreenshot();
    });
  }

  static void _onGalleryChanged(MethodCall call) {
    print('DEBUG: Gallery change detected: ${call.method}');
    _checkForNewScreenshot();
  }

  static Future<void> _checkForNewScreenshot({bool isInitial = false}) async {
    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true, // Much faster - only looks at the "Recent" album
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

      // Handle each of the recent assets to ensure no skips
      for (final AssetEntity latest in entities) {
        if (latest.id == _lastImageId) break; // Reached already handled assets
        
        final DateTime now = DateTime.now();
        final bool isVeryRecent = now.difference(latest.createDateTime).inSeconds.abs() < 300;

        // On first run, we only care about screenshots taken while the app was starting
        if (isInitial && !isVeryRecent) continue;

        if (isScreenshot(latest)) {
          print('DEBUG: Screenshot confirmed! Adding to stream: ${latest.id}');
          _screenshotStream.add(latest);
        }
      }

      // Update baseline to the latest seen
      _lastImageId = entities[0].id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastId, _lastImageId!);
    } catch (e) {
      print('DEBUG: Error checking for screenshots: $e');
    }
  }

  static bool isScreenshot(AssetEntity asset) {
    final String title = asset.title?.toLowerCase() ?? '';
    final String path = asset.relativePath?.toLowerCase() ?? '';
    
    // Check title (filename)
    // Adding common patterns like 'screencapture', 'screen-shot', and brand specific ones
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
    // Some phones use 'ScreenCapture' or 'Screencaps' folders
    final bool matchesPath = path.contains('screenshot') || 
                             path.contains('screencap') ||
                             path.contains('capture') ||
                             path.contains('screencapture') ||
                             path.contains('screen-shot') ||
                             path.contains('screen_shot');
                             
    return matchesTitle || matchesPath;
  }

  static void stopMonitoring() {
    _fallbackTimer?.cancel();
    PhotoManager.removeChangeCallback(_onGalleryChanged);
    PhotoManager.stopChangeNotify();
  }
}