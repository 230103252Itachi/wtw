import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

Future<File> compressImage(File file) async {
  try {
    final dir = file.parent.path;
    final basename = p.basenameWithoutExtension(file.path);
    final ext = p.extension(file.path);
    final targetPath = '$dir/${basename}_small$ext';

    final Object? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 40,
      minWidth: 800,
      minHeight: 800,
    );

    if (result is File) {
      return result;
    }

    if (result is Uint8List || result is List<int>) {
      final outFile = File(targetPath);
      await outFile.writeAsBytes(result as List<int>);
      return outFile;
    }

    return file;
  } catch (e) {
    return file;
  }
}
