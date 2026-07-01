import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/progress_repository.dart';
import 'data/repositories/level_repository.dart';
import 'ads/ad_manager.dart';
import 'core/audio_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AudioManager
  await AudioManager.instance.initialize();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Init AdMob
  await MobileAds.instance.initialize();

  // Init SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final progressRepo = ProgressRepository(prefs);
  final levelRepo = LevelRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => progressRepo),
        Provider<LevelRepository>(create: (_) => levelRepo),
        Provider<AdManager>(create: (_) => AdManager()..initialize()),
      ],
      child: const ArrowPuzzleApp(),
    ),
  );
}
