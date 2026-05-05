import 'package:hive/hive.dart';

part 'screenshot_item.g.dart';

@HiveType(typeId: 0)
class ScreenshotItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String path;

  @HiveField(2)
  String note;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5, defaultValue: false)
  bool isFavorite;

  @HiveField(6, defaultValue: 'Uncategorized')
  String category;

  @HiveField(7, defaultValue: '')
  String extractedText;

  ScreenshotItem({
    required this.id,
    required this.path,
    this.note = '',
    required this.createdAt,
    this.isFavorite = false,
    this.category = 'Uncategorized',
    this.extractedText = '',
  });
}
