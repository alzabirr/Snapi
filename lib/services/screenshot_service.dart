import 'dart:async';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

class ScreenshotService {
  static String? _lastImageId;
  static final StreamController<AssetEntity> _screenshotStream = StreamController<AssetEntity>.broadcast();

  static Stream<AssetEntity> get screenshotStream => _screenshotStream.stream;

  static Future<void> startMonitoring() async {
    // Check permission first
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && ps != PermissionState.limited) {
      print('DEBUG: Screenshot monitoring failed - Permission denied: $ps');
      return;
    }
    print('DEBUG: Screenshot monitoring starting with permission: $ps');

    // Initial check to set baseline
    await _checkForNewScreenshot(isInitial: true);

    // Use PhotoManager change notification instead of Timer for better battery life
    PhotoManager.addChangeCallback(_onGalleryChanged);
    PhotoManager.startChangeNotify();
  }

  static void _onGalleryChanged(MethodCall call) {
    print('DEBUG: Gallery change detected: ${call.method}');
    _checkForNewScreenshot();
  }

  static Future<void> _checkForNewScreenshot({bool isInitial = false}) async {
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
      
      if (isInitial) {
        print('DEBUG: First Run - setting baseline ID: ${latest.id}');
        _lastImageId = latest.id;

        final DateTime now = DateTime.now();
        final bool isVeryRecent = now.difference(latest.createDateTime).inSeconds.abs() < 30;

        if (isVeryRecent && _isScreenshot(latest)) {
          print('DEBUG: Found fresh screenshot on startup! Triggering popup.');
          _screenshotStream.add(latest);
        }
        return;
      }

      if (_lastImageId != latest.id) {
        print('DEBUG: Change detected! New ID: ${latest.id}');
        if (_isScreenshot(latest)) {
          print('DEBUG: Screenshot confirmed! Adding to stream.');
          _screenshotStream.add(latest);
        }
        _lastImageId = latest.id;
      }
    } catch (e) {
      print('DEBUG: Error checking for screenshots: $e');
    }
  }

  static bool _isScreenshot(AssetEntity asset) {
    final String title = asset.title?.toLowerCase() ?? '';
    final String path = asset.relativePath?.toLowerCase() ?? '';
    return title.contains('screenshot') || 
           title.contains('scr_') || 
           path.contains('screenshot');
  }

  static void stopMonitoring() {
    PhotoManager.removeChangeCallback(_onGalleryChanged);
    PhotoManager.stopChangeNotify();
  }
}
