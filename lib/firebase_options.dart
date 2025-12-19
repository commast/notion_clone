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
        return macos;
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'AIzaSyDYdyVg8bEbeQLb8cc6bGSn-tfSm35nxKw',
    appId: '1:794411661036:web:fc1bb3e80ca0fc5ee657c9',
    messagingSenderId: '794411661036',
    projectId: 'notion-clone-2025',
    authDomain: 'notion-clone-2025.firebaseapp.com',
    storageBucket: 'notion-clone-2025.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDpjCHGH4C89vhyhzu-fKuKwam8Zn-OpJU',
    appId: '1:794411661036:android:c5f3d3a8298c1733e657c9',
    messagingSenderId: '794411661036',
    projectId: 'notion-clone-2025',
    storageBucket: 'notion-clone-2025.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCIa8iqVsbd5yLwV0i0KPhKkGyEhbgvf2o',
    appId: '1:794411661036:ios:c4ff40451edf465fe657c9',
    messagingSenderId: '794411661036',
    projectId: 'notion-clone-2025',
    storageBucket: 'notion-clone-2025.firebasestorage.app',
    iosBundleId: 'com.example.notionClone2',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCIa8iqVsbd5yLwV0i0KPhKkGyEhbgvf2o',
    appId: '1:794411661036:ios:c4ff40451edf465fe657c9',
    messagingSenderId: '794411661036',
    projectId: 'notion-clone-2025',
    storageBucket: 'notion-clone-2025.firebasestorage.app',
    iosBundleId: 'com.example.notionClone2',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDYdyVg8bEbeQLb8cc6bGSn-tfSm35nxKw',
    appId: '1:794411661036:web:2e12b98a563f8146e657c9',
    messagingSenderId: '794411661036',
    projectId: 'notion-clone-2025',
    authDomain: 'notion-clone-2025.firebaseapp.com',
    storageBucket: 'notion-clone-2025.firebasestorage.app',
  );
}
