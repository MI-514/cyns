import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload an image file to Firebase Storage under a specified path
  static Future<String?> uploadImage({
    required File file,
    required String folder,
    required String filename,
  }) async {
    try {
      final ext = p.extension(file.path);
      final ref = _storage.ref().child('$folder/$filename$ext');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }
}
