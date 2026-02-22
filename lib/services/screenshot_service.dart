import 'dart:async';
import 'package:photo_manager/photo_manager.dart';

class ScreenshotService {
  static Timer? _timer;
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

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _checkForNewScreenshot();
    });
  }

  static Future<void> _checkForNewScreenshot() async {
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
    final bool isVeryRecent = now.difference(latest.createDateTime).inSeconds.abs() < 60;

    // print('DEBUG: Latest Check -> ID: ${latest.id}, Created: ${latest.createDateTime}, Recent: $isVeryRecent');
    
    if (_lastImageId == null) {
      print('DEBUG: First Run - setting baseline ID: ${latest.id}');
      _lastImageId = latest.id;
      
      if (isVeryRecent) {
        if (_isScreenshot(latest)) {
          print('DEBUG: Found fresh screenshot on startup! Triggering popup.');
          _screenshotStream.add(latest);
        }
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
  }

  static bool _isScreenshot(AssetEntity asset) {
    final String title = asset.title?.toLowerCase() ?? '';
    final String path = asset.relativePath?.toLowerCase() ?? '';
    return title.contains('screenshot') || 
           title.contains('scr_') || 
           path.contains('screenshot');
  }

  static void stopMonitoring() {
    _timer?.cancel();
  }
}
