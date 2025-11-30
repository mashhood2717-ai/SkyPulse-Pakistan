import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAGZubwEXdVU4Zor9st0l27zKVBkFVGEcw',
    appId: '1:1062690430472:web:045e0ad1362f3cbbd0bbbd',
    messagingSenderId: '1062690430472',
    projectId: 'skypulse-pakistan',
    authDomain: 'skypulse-pakistan.firebaseapp.com',
    databaseURL: 'https://skypulse-pakistan.firebaseio.com',
    storageBucket: 'skypulse-pakistan.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGZubwEXdVU4Zor9st0l27zKVBkFVGEcw',
    appId: '1:1062690430472:android:045e0ad1362f3cbbd0bbbd',
    messagingSenderId: '1062690430472',
    projectId: 'skypulse-pakistan',
    storageBucket: 'skypulse-pakistan.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGZubwEXdVU4Zor9st0l27zKVBkFVGEcw',
    appId: '1:1062690430472:ios:045e0ad1362f3cbbd0bbbd',
    messagingSenderId: '1062690430472',
    projectId: 'skypulse-pakistan',
    storageBucket: 'skypulse-pakistan.firebasestorage.app',
    iosBundleId: 'com.mashhood.skypulse',
  );
}
