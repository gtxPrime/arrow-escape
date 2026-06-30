

// Core game constants
class AppConstants {
  AppConstants._();

  // App identity
  static const String appName = 'Arrow Out';
  static const String packageId = 'com.gxdevs.arrowout';

  // Grid sizes: 10×10 minimum at level 1, up to 40×40 at very high levels.
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
  static const String unityRewardedAdId = 'Rewarded_Android';
  static const bool   unityTestMode     = true;

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

  /// Grid size for a given level number.
  ///   Normal :  10×10 at level 4, grows to 30×30 around level 180.
  ///   Boss/God: fixed 30×30.
  static int gridSizeForLevel(int level) {
    if (level <= tutorialLevels) {
      final raw = (10 + level * 0.06).round();
      return raw.clamp(10, 40);
    }
    final type = levelTypeFor(level);
    // Boss / God → fixed 30×30
    if (type == LevelType.boss || type == LevelType.god) {
      return 30;
    }
    // Normal: ramp 10×10 (level 4) → 30×30 (level ~177)
    final raw = (10 + (level - tutorialLevels) * 0.115).round();
    return raw.clamp(10, 30);
  }

  /// Returns the level type: tutorial, god, boss, or normal.
  static LevelType levelTypeFor(int level) {
    if (level <= tutorialLevels) return LevelType.tutorial;
    if (level % godLevelEvery  == 0) return LevelType.god;
    if (level % bossLevelEvery == 0) return LevelType.boss;
    return LevelType.normal;
  }

  /// Clean standalone helper: true when n is a boss level.
  static bool isBossLevel(int n) => n % bossLevelEvery == 0 && !isGodLevel(n);

  /// True for god levels (every 15th, overrides boss).
  static bool isGodLevel(int n) => n % godLevelEvery == 0;

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
