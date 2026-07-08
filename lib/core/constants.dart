

// Core game constants
class AppConstants {
  AppConstants._();

  // App identity
  static const String appName = 'Arrow Escape';
  static const String packageId = 'com.arrowx.escape';

  // Grid sizes: 10×10 minimum at level 1, up to 35×35 target (hard cap 40).
  // • Normal: 10×10 at level 4 → 35×35 around level 300+
  // • Boss:   20×20 at first boss → 30×30 at high cycles
  // • God:    22×22 at first god  → 35×35 at high cycles
  static const int startingGridSize = 10;
  static const int maxGridSize = 40;
  static const int tutorialLevels = 3;

  // Lives
  static const int maxLives = 3;

  // Special level cadence
  static const int bossLevelEvery = 3;   // Every 3rd level is BOSS
  static const int godLevelEvery  = 5;   // Every 5th level is GOD (overrides boss)

  // Ads (Test IDs — replace before publishing)
  static const String admobAppIdAndroid    = 'ca-app-pub-3940256099942544~3347511713';
  static const String admobBannerUnitId    = 'ca-app-pub-3940256099942544/6300978111';
  static const String admobInterstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String admobRewardedUnitId  = 'ca-app-pub-3940256099942544/5224354917';

  static const String unityGameId       = 'YOUR_UNITY_GAME_ID';
  static const String unityBannerAdId   = 'Banner_Android';
  static const String unityInterstitialAdId = 'Interstitial_Android';
  static const String unityRewardedAdId = 'Rewarded_Android';
  static const bool   unityTestMode     = true;

  // static const String applovinSdkKey = 'YOUR_APPLOVIN_SDK_KEY';
  // static const String applovinBannerAdId = 'YOUR_APPLOVIN_BANNER_AD_UNIT_ID';
  // static const String applovinInterstitialAdId = 'YOUR_APPLOVIN_INTERSTITIAL_AD_UNIT_ID';
  // static const String applovinRewardedAdId = 'YOUR_APPLOVIN_REWARDED_AD_UNIT_ID';

  // Dev Mode Feature Toggle
  /// Set to [true] to allow long-pressing the game title on the main menu to
  /// toggle Dev Mode (all levels unlocked, no life penalty).
  /// Set to [false] to fully disable Dev Mode in production builds.
  static const bool enableDevMode = true;

  // Ad Network Feature Toggles
  static const bool enableAdMob = false;
  static const bool enableUnityAds = false;
  static const bool enableAppLovin = false;

  static const int interstitialEveryNLevels = 4;

  // Animation durations
  static const Duration arrowSlideDuration   = Duration(milliseconds: 220);
  // arrowExitDuration is now dynamic (based on path length) — this is the base
  static const Duration arrowExitDuration    = Duration(milliseconds: 300);
  static const Duration arrowShakeDuration   = Duration(milliseconds: 400);
  static const Duration levelCompleteDuration = Duration(milliseconds: 600);

  // Scoring
  static const int baseScore           = 100;
  static const int bonusPerRemainingLife = 50;
  static const int bossBonus           = 200;
  static const int godBonus            = 500;

  // Streak milestones
  static const int streakMilestone1 = 7;
  static const int streakMilestone2 = 30;
  static const int streakMilestone3 = 100;

  /// How many boss levels have occurred up to and including [level].
  static int bossCycleCount(int level) {
    if (level <= tutorialLevels) return 0;
    int count = 0;
    for (int l = tutorialLevels + 1; l <= level; l++) {
      if (levelTypeFor(l) == LevelType.boss) count++;
    }
    return count;
  }

  /// How many god levels have occurred up to and including [level].
  static int godCycleCount(int level) {
    if (level <= tutorialLevels) return 0;
    int count = 0;
    for (int l = tutorialLevels + 1; l <= level; l++) {
      if (levelTypeFor(l) == LevelType.god) count++;
    }
    return count;
  }

  /// Grid size for a given level number.
  ///   Tutorial :  10×10 (fixed small canvas for guidance)
  ///   Normal   :  15×15 minimum at level 4, ramps to 24×24 at level 19
  ///               25×25 minimum at level 20, ramps to 35×35 at level 500
  ///   Boss     :  27×27 minimum at 1st cycle, ramps to 40×40 at cycle ~20
  ///   God      :  27×27 minimum at 1st cycle, ramps to 40×40 at cycle ~20
  static int gridSizeForLevel(int level) {
    if (level <= tutorialLevels) return 10;

    final type = levelTypeFor(level);

    if (type == LevelType.boss) {
      // Scale 27 → 40 over ~20 boss cycles, then hold at 40.
      final cycle = bossCycleCount(level);
      final raw = 27 + ((cycle - 1) * (13.0 / 19.0)).round();
      return raw.clamp(27, 40);
    }

    if (type == LevelType.god) {
      // Scale 27 → 40 over ~20 god cycles, then hold at 40.
      final cycle = godCycleCount(level);
      final raw = 27 + ((cycle - 1) * (13.0 / 19.0)).round();
      return raw.clamp(27, 40);
    }

    // Normal levels:
    if (level < 20) {
      // Level 4 to 19: min 15, scale gently up to 24.
      final raw = 15 + ((level - 4) * (9.0 / 15.0)).round();
      return raw.clamp(15, 24);
    } else {
      // Level 20+: min 25, scale up to 35.
      final raw = 25 + ((level - 20) * (10.0 / 480.0)).round();
      return raw.clamp(25, 35);
    }
  }


  /// Returns the level type: tutorial, god, boss, or normal.
  ///
  /// Post-tutorial pattern repeats every 7 levels:
  ///   [N, N, N, Boss, N, N, God]
  ///   pos 1-3 → Normal
  ///   pos 4   → Boss
  ///   pos 5-6 → Normal
  ///   pos 7   → God
  static LevelType levelTypeFor(int level) {
    if (level <= tutorialLevels) return LevelType.tutorial;
    // position within the 7-level cycle (1-indexed)
    final pos = ((level - tutorialLevels - 1) % 7) + 1;
    if (pos == 7) return LevelType.god;
    if (pos == 4) return LevelType.boss;
    return LevelType.normal;
  }

  /// Clean standalone helper: true when n is a boss level.
  static bool isBossLevel(int n) => levelTypeFor(n) == LevelType.boss;

  /// True for god levels.
  static bool isGodLevel(int n) => levelTypeFor(n) == LevelType.god;

  /// Canvas scale factor: boss/god levels use more screen space for larger canvases.
  static double canvasScaleForType(LevelType type) {
    switch (type) {
      case LevelType.god:  return 0.93;
      case LevelType.boss: return 0.93;
      default:             return 0.90;
    }
  }
}

enum LevelType {
  tutorial,
  normal,
  boss,
  god;

  String get label {
    switch (this) {
      case LevelType.tutorial: return 'Tutorial';
      case LevelType.normal:   return '';
      case LevelType.boss:     return 'Boss';
      case LevelType.god:      return 'God';
    }
  }

  bool get isSpecial => this == LevelType.boss || this == LevelType.god;
}
