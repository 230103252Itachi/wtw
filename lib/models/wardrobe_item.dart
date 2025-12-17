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

  @HiveField(2)
  dynamic metadata; // Stores AI data from Firestore

  @HiveField(3)
  String? id; // Firebase document ID

  WardrobeItem({required this.imagePath, required this.title, this.metadata, this.id});

  // Check if path is a URL (from Firebase) or local file path
  bool get isNetworkImage => imagePath.startsWith('http');

  Future<File?> get image async {
    if (isNetworkImage) return null; // Network images don't need File
    final file = File(imagePath);
    return file.existsSync() ? file : null;
  }

  Widget get imageWidget {
    if (isNetworkImage) {
      // Show network image from Firebase
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/placeholder.png',
            fit: BoxFit.cover,
          );
        },
      );
    }
    
    // Show local file
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

  Map<String, dynamic> toJson() {
    return {'id': key?.toString(), 'imagePath': imagePath, 'category': title};
  }

  static WardrobeItem fromJson(Map<String, dynamic> map) {
    return WardrobeItem(
      imagePath: map['imagePath'] as String? ?? '',
      title: map['category'] as String? ?? '',
    );
  }
}
