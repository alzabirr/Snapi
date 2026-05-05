import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/screenshot_item.dart';

class DatabaseService {
  static final ValueNotifier<int> categoryNotifier = ValueNotifier<int>(0);
  
  static const String boxName = 'screenshots';
  static const String deletedBoxName = 'deleted_screenshots';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) { // 0 is default id if not specified in @HiveType
      try {
        Hive.registerAdapter(ScreenshotItemAdapter());
      } catch (_) {
        // Fallback if ID is different or already registered
      }
    }
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<ScreenshotItem>(boxName);
    }
    if (!Hive.isBoxOpen(deletedBoxName)) {
      await Hive.openBox<ScreenshotItem>(deletedBoxName);
    }
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
    final clone = ScreenshotItem(
      id: item.id,
      path: item.path,
      note: item.note,
      createdAt: item.createdAt,
      isFavorite: item.isFavorite,
      category: item.category,
      extractedText: item.extractedText,
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
      createdAt: item.createdAt,
      isFavorite: item.isFavorite,
      category: item.category,
      extractedText: item.extractedText,
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

  static Future<void> deleteCategory(String categoryName) async {
    final itemsToDelete = box.values.where((item) => 
      item.category == categoryName || (categoryName == 'General' && item.category.isEmpty)
    ).toList();
    for (var item in itemsToDelete) {
      await deleteItem(item);
    }
  }

  static Future<void> renameCategory(String oldName, String newName) async {
    final Map<dynamic, ScreenshotItem> updates = {};
    final itemsToUpdate = box.values.where((item) => item.category == oldName).toList();
    
    for (var item in itemsToUpdate) {
      item.category = newName;
      updates[item.id] = item;
    }
    
    if (updates.isNotEmpty) {
      await box.putAll(updates);
    }
  }
}
