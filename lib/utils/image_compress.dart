// lib/utils/image_compress.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

/// Compress image to smaller file to reduce upload size / token usage.
/// Returns compressed file or original when compression failed.
Future<File> compressImage(File file) async {
  try {
    final dir = file.parent.path;
    final basename = p.basenameWithoutExtension(file.path);
    final ext = p.extension(file.path);
    final targetPath = '$dir/${basename}_small$ext';

    final Object? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 40, // tune 30..60
      minWidth: 800,
      minHeight: 800,
    );

    // case: plugin returned a File
    if (result is File) {
      return result;
    }

    // case: plugin returned raw bytes
    if (result is Uint8List || result is List<int>) {
      final outFile = File(targetPath);
      await outFile.writeAsBytes(result as List<int>);
      return outFile;
    }

    // unknown return — fallback to original file
    return file;
  } catch (e) {
    // on error return original
    return file;
  }
}
