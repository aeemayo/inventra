import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'firebase_options.dart';

/// Initialize Firebase, Hive, and system UI
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // System UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase
  if (defaultTargetPlatform == TargetPlatform.linux) {
    debugPrint(
      'Firebase initialization is skipped on Linux desktop for this setup. '
      'Use a supported target (Android/iOS/Web/macOS/Windows) or add Linux-specific Firebase support if needed.',
    );
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Hive (local storage)
  await Hive.initFlutter();
  // Register adapters here when implementing offline cache
}
