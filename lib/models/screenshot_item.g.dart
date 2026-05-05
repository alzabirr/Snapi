// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screenshot_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScreenshotItemAdapter extends TypeAdapter<ScreenshotItem> {
  @override
  final int typeId = 0;

  @override
  ScreenshotItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScreenshotItem(
      id: fields[0] as String,
      path: fields[1] as String,
      note: fields[2] as String,
      createdAt: fields[4] as DateTime,
      isFavorite: fields[5] == null ? false : fields[5] as bool,
      category: fields[6] == null ? 'Uncategorized' : fields[6] as String,
      extractedText: fields[7] == null ? '' : fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ScreenshotItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.extractedText);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenshotItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
