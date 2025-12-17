// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wardrobe_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WardrobeItemAdapter extends TypeAdapter<WardrobeItem> {
  @override
  final int typeId = 0;

  @override
  WardrobeItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WardrobeItem(
      imagePath: fields[0] as String,
      title: fields[1] as String,
      metadata: fields[2] as dynamic,
      id: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WardrobeItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.imagePath)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.metadata)
      ..writeByte(3)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WardrobeItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
