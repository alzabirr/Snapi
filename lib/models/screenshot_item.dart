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

  @HiveField(3)
  DateTime? reminderTime;

  @HiveField(4)
  final DateTime createdAt;

  ScreenshotItem({
    required this.id,
    required this.path,
    this.note = '',
    this.reminderTime,
    required this.createdAt,
  });
}
