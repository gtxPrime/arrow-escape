import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';

import 'app.dart';
import 'data/repositories/progress_repository.dart';
import 'data/repositories/level_repository.dart';
import 'ads/ad_manager.dart';
import 'core/audio_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Initialize Firebase & Crashlytics safely
  try {
    await Firebase.initializeApp();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Firebase/Crashlytics init error: $e');

    // Fallback handlers if Firebase is not yet configured or fails
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter framework error: ${details.exception}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Async platform error: $error');
      return true;
    };
  }

  // 1. Initialize AudioManager safely
  try {
    await AudioManager.instance.initialize();
  } catch (e) {
    debugPrint('AudioManager init error: $e');
  }

  // 2. Lock to portrait safely
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  } catch (e) {
    debugPrint('Orientations init error: $e');
  }

  // 3. Edge-to-edge system UI safely
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  } catch (e) {
    debugPrint('System UI init error: $e');
  }

  // 4. Init MobileAds safely
  if (AppConstants.enableAdMob) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds init error: $e');
    }
  }

  // 5. Init SharedPreferences & Repositories safely
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences init error: $e');
  }

  final progressRepo = ProgressRepository(prefs);
  final levelRepo = LevelRepository(prefs);

  try {
    await levelRepo.loadPregeneratedLevels();
  } catch (e) {
    debugPrint('LevelRepository init error: $e');
  }

  // 6. Init AdManager safely
  final adManager = AdManager();
  try {
    adManager.initialize();
  } catch (e) {
    debugPrint('AdManager init error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => progressRepo),
        Provider<LevelRepository>(create: (_) => levelRepo),
        Provider<AdManager>(create: (_) => adManager),
      ],
      child: const ArrowPuzzleApp(),
    ),
  );
}
