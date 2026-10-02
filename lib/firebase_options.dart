// File generated from the owner's Firebase console downloads
// (google-services.json + GoogleService-Info.plist), mirroring what
// `flutterfire configure` produces. See PUBLISHING.md.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        're-run flutterfire configure to add web support.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          're-run flutterfire configure to add macos support.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          're-run flutterfire configure to add windows support.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          're-run flutterfire configure to add linux support.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAAqWagTs93zq-TpMTcMnY0KxnDsa0NVlY',
    appId: '1:616266839186:android:511e8710a88b06e6c8a24b',
    messagingSenderId: '616266839186',
    projectId: 'gotrvl-4aae4',
    storageBucket: 'gotrvl-4aae4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBZESy8bDzuS9vtQlak1wgnOw60vMwAjlU',
    appId: '1:616266839186:ios:d4106b81c40abaafc8a24b',
    messagingSenderId: '616266839186',
    projectId: 'gotrvl-4aae4',
    storageBucket: 'gotrvl-4aae4.firebasestorage.app',
    iosBundleId: 'com.gotrvl.app',
  );
}
