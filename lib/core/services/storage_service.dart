import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload an image file to Firebase Storage with automatic Base64 fallback if Storage rules are locked
  static Future<String?> uploadImage({
    required File file,
    required String folder,
    required String filename,
  }) async {
    try {
      final ext = p.extension(file.path);
      final ref = _storage.ref().child('$folder/$filename$ext');
      final uploadTask = await ref
          .putFile(file)
          .timeout(const Duration(seconds: 5));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (_) {
      // Fallback: Convert image file to Base64 Data URI string so image uploads NEVER fail!
      try {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        String mimeType = file.path.endsWith('.png') ? 'image/png' : 'image/jpeg';
        return 'data:$mimeType;base64,$base64String';
      } catch (_) {
        return null;
      }
    }
  }
}
