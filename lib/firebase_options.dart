import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for CYN application.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyARfHfMniLlzAD6ZnKGNg2Y7fQ4AaJyDdE',
    appId: '1:724329772950:web:3fada5989116960b1d0fb7',
    messagingSenderId: '724329772950',
    projectId: 'cyns-f77ec',
    authDomain: 'cyns-f77ec.firebaseapp.com',
    storageBucket: 'cyns-f77ec.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcYnvPdBNkj36AAirGwhZ1rBrW4Z9B5Zg',
    appId: '1:724329772950:android:696bbb788951d7ce1d0fb7',
    messagingSenderId: '724329772950',
    projectId: 'cyns-f77ec',
    storageBucket: 'cyns-f77ec.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCBpI0gxXxMUvY1YnI_mefZhR23qpgm_eY',
    appId: '1:724329772950:ios:63a2f175f27935c61d0fb7',
    messagingSenderId: '724329772950',
    projectId: 'cyns-f77ec',
    storageBucket: 'cyns-f77ec.firebasestorage.app',
    iosClientId: '724329772950-7bbrrmh9dn1tqc9lf9g6ntg4b80akl39.apps.googleusercontent.com',
    iosBundleId: 'com.example.cyns',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCBpI0gxXxMUvY1YnI_mefZhR23qpgm_eY',
    appId: '1:724329772950:ios:63a2f175f27935c61d0fb7',
    messagingSenderId: '724329772950',
    projectId: 'cyns-f77ec',
    storageBucket: 'cyns-f77ec.firebasestorage.app',
    iosClientId: '724329772950-7bbrrmh9dn1tqc9lf9g6ntg4b80akl39.apps.googleusercontent.com',
    iosBundleId: 'com.example.cyns',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyARfHfMniLlzAD6ZnKGNg2Y7fQ4AaJyDdE',
    appId: '1:724329772950:web:d08b36174ccbc0dd1d0fb7',
    messagingSenderId: '724329772950',
    projectId: 'cyns-f77ec',
    authDomain: 'cyns-f77ec.firebaseapp.com',
    storageBucket: 'cyns-f77ec.firebasestorage.app',
  );
}
