import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'wardrobe_item.g.dart';

@HiveType(typeId: 0)
class WardrobeItem extends HiveObject {
  @HiveField(0)
  String imagePath;

  @HiveField(1)
  String title;

  WardrobeItem({required this.imagePath, required this.title});

  Future<File?> get image async {
    final file = File(imagePath);
    return file.existsSync() ? file : null;
  }

  Widget get imageWidget {
    return FutureBuilder<File?>(
      future: image,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data != null) {
          return Image.file(snapshot.data!, fit: BoxFit.cover);
        } else {
          return Image.asset(
            'assets/images/placeholder.png',
            fit: BoxFit.cover,
          );
        }
      },
    );
  }

  /// Serializes the WardrobeItem to a JSON-compatible map.
  /// Includes `id` when the item is saved in Hive (key is available).
  Map<String, dynamic> toJson() {
    return {'id': key?.toString(), 'imagePath': imagePath, 'category': title};
  }

  /// Creates a WardrobeItem from a JSON map.
  /// Note: when creating fromJson for Hive you still need to save it to a box.
  static WardrobeItem fromJson(Map<String, dynamic> map) {
    return WardrobeItem(
      imagePath: map['imagePath'] as String? ?? '',
      title: map['category'] as String? ?? '',
    );
  }
}
