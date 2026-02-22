import 'package:hive_flutter/hive_flutter.dart';
import '../models/screenshot_item.dart';

class DatabaseService {
  static const String boxName = 'screenshots';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ScreenshotItemAdapter());
    await Hive.openBox<ScreenshotItem>(boxName);
  }

  static Box<ScreenshotItem> get box => Hive.box<ScreenshotItem>(boxName);

  static Future<void> addItem(ScreenshotItem item) async {
    await box.put(item.id, item);
  }

  static Future<void> updateItem(ScreenshotItem item) async {
    await item.save();
  }

  static Future<void> deleteItem(ScreenshotItem item) async {
    await item.delete();
  }

  static List<ScreenshotItem> getAllItems() {
    return box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
