// Helper utilities for picking images and uploading to a backend (or converting to base64)
// This file does NOT change your UI. It provides functions you can call from your screens.
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WardrobePhotoHelper {
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from camera or gallery.
  /// source: ImageSource.camera or ImageSource.gallery
  Future<File?> pickImage({required ImageSource source}) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Convert a File to data:image/...;base64 string
  Future<String> fileToBase64DataUri(File file) async {
    final bytes = await file.readAsBytes();
    final mime = _detectMimeType(file.path);
    final base64Image = base64Encode(bytes);
    return 'data:$mime;base64,$base64Image';
  }

  Future<File> saveImagePermanently(File image) async {
    final dir = await getApplicationDocumentsDirectory();
    final newPath = p.join(
      dir.path,
      "${DateTime.now().millisecondsSinceEpoch}.jpg",
    );
    return await image.copy(newPath);
  }

  String _detectMimeType(String path) {
    final ext = path.toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  /// Upload image file to your backend which should accept multipart/form-data.
  /// Returns parsed JSON response from server.
  Future<Map<String, dynamic>> uploadToBackend({
    required String url,
    required File file,
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(url);
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(headers ?? {});
    fields?.forEach((k, v) => req.fields[k] = v);
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Upload error: ${streamed.statusCode} $body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
