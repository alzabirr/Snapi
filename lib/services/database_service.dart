import 'package:hive_flutter/hive_flutter.dart';
import '../models/screenshot_item.dart';

class DatabaseService {
  static const String boxName = 'screenshots';
  static const String deletedBoxName = 'deleted_screenshots';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ScreenshotItemAdapter());
    await Hive.openBox<ScreenshotItem>(boxName);
    await Hive.openBox<ScreenshotItem>(deletedBoxName);
  }

  static Box<ScreenshotItem> get box => Hive.box<ScreenshotItem>(boxName);
  static Box<ScreenshotItem> get deletedBox => Hive.box<ScreenshotItem>(deletedBoxName);

  static Future<void> addItem(ScreenshotItem item) async {
    await box.put(item.id, item);
  }

  static Future<void> updateItem(ScreenshotItem item) async {
    await item.save();
  }

  // Moves to Recycle Bin instead of permanent deletion
  static Future<void> deleteItem(ScreenshotItem item) async {
    // Clone the item to avoid Hive Object state issues
    final clone = ScreenshotItem(
      id: item.id,
      path: item.path,
      note: item.note,
      reminderTime: item.reminderTime,
      createdAt: item.createdAt,
      isFavorite: item.isFavorite,
      category: item.category,
    );
    await deletedBox.put(clone.id, clone);
    await item.delete();
  }

  // Restore from Recycle Bin
  static Future<void> restoreItem(ScreenshotItem item) async {
    final clone = ScreenshotItem(
      id: item.id,
      path: item.path,
      note: item.note,
      reminderTime: item.reminderTime,
      createdAt: item.createdAt,
      isFavorite: item.isFavorite,
      category: item.category,
    );
    await box.put(clone.id, clone);
    await item.delete();
  }

  // Permanently delete an item
  static Future<void> permanentlyDeleteItem(ScreenshotItem item) async {
    await item.delete();
  }

  static List<ScreenshotItem> getAllItems() {
    return box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static List<ScreenshotItem> getDeletedItems() {
    return deletedBox.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> emptyRecycleBin() async {
    await deletedBox.clear();
  }
}
