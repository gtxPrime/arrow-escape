import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:applovin_max/applovin_max.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// Central ad orchestrator — manages banner, interstitial, and rewarded ads.
/// Uses a 3-level waterfall fallback strategy: AdMob (Priority 1) -> AppLovin (Priority 2) -> Unity Ads (Priority 3).
/// Each ad network can be toggled on/off dynamically in AppConstants.
class AdManager {
  // ── AdMob state ──────────────────────────────────────────────────────────────
  InterstitialAd? _admobInterstitial;
  bool _isAdmobInterstitialLoaded = false;

  RewardedAd? _admobRewarded;
  bool _isAdmobRewardedLoaded = false;
  int _levelsSinceLastInterstitial = 0;

  // ── AppLovin state ───────────────────────────────────────────────────────────
  bool _isApplovinInitialized = false;
  bool _isApplovinInterstitialLoaded = false;
  bool _isApplovinRewardedLoaded = false;

  Completer<void>? _applovinInterstitialCompleter;
  void Function()? _applovinRewardedSuccessCallback;
  void Function()? _applovinRewardedDismissCallback;

  // ── Unity Ads state ───────────────────────────────────────────────────────────
  bool _isUnityInitialized = false;
  bool _isUnityInterstitialLoaded = false;
  bool _isUnityRewardedLoaded = false;

  // ── Initialization ────────────────────────────────────────────────────────────
  void initialize() {
    // 1. Initialize and load AdMob if enabled
    if (AppConstants.enableAdMob) {
      _loadAdmobInterstitial();
      _loadAdmobRewarded();
    }

    // 2. Initialize and load AppLovin MAX if enabled
    if (AppConstants.enableAppLovin) {
      AppLovinMAX.initialize(AppConstants.applovinSdkKey).then((sdkConfiguration) {
        if (sdkConfiguration != null) {
          _isApplovinInitialized = true;
          _attachApplovinListeners();
          _loadApplovinInterstitial();
          _loadApplovinRewarded();
        }
      }).catchError((e) {
        debugPrint('AppLovin MAX Initialization failed: $e');
      });
    }

    // 3. Initialize and load Unity Ads if enabled
    if (AppConstants.enableUnityAds) {
      UnityAds.init(
        gameId: AppConstants.unityGameId,
        testMode: AppConstants.unityTestMode,
        onComplete: () {
          _isUnityInitialized = true;
          _loadUnityInterstitial();
          _loadUnityRewarded();
        },
        onFailed: (error, message) {
          _isUnityInitialized = false;
          debugPrint('Unity Ads Initialization failed: $error - $message');
        },
      );
    }
  }

  // ── AdMob Loading ─────────────────────────────────────────────────────────────
  void _loadAdmobInterstitial() {
    if (!AppConstants.enableAdMob) return;
    InterstitialAd.load(
      adUnitId: AppConstants.admobInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _admobInterstitial = ad;
          _isAdmobInterstitialLoaded = true;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _isAdmobInterstitialLoaded = false;
          _admobInterstitial = null;
          // Retry after delay
          Future.delayed(const Duration(seconds: 15), () => _loadAdmobInterstitial());
        },
      ),
    );
  }

  void _loadAdmobRewarded() {
    if (!AppConstants.enableAdMob) return;
    RewardedAd.load(
      adUnitId: AppConstants.admobRewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _admobRewarded = ad;
          _isAdmobRewardedLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _isAdmobRewardedLoaded = false;
          _admobRewarded = null;
          // Retry after delay
          Future.delayed(const Duration(seconds: 15), () => _loadAdmobRewarded());
        },
      ),
    );
  }

  // ── AppLovin Listeners ────────────────────────────────────────────────────────
  void _attachApplovinListeners() {
    if (!AppConstants.enableAppLovin) return;
    // Interstitial
    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) {
        _isApplovinInterstitialLoaded = true;
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        _isApplovinInterstitialLoaded = false;
        Future.delayed(const Duration(seconds: 15), () => _loadApplovinInterstitial());
      },
      onAdDisplayedCallback: (ad) {
        _isApplovinInterstitialLoaded = false;
      },
      onAdDisplayFailedCallback: (ad, error) {
        _isApplovinInterstitialLoaded = false;
        _loadApplovinInterstitial();
        if (_applovinInterstitialCompleter != null && !_applovinInterstitialCompleter!.isCompleted) {
          _showUnityInterstitial(_applovinInterstitialCompleter!);
          _applovinInterstitialCompleter = null;
        }
      },
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) {
        _isApplovinInterstitialLoaded = false;
        _loadApplovinInterstitial();
        if (_applovinInterstitialCompleter != null && !_applovinInterstitialCompleter!.isCompleted) {
          _applovinInterstitialCompleter!.complete();
          _applovinInterstitialCompleter = null;
        }
      },
      onAdRevenuePaidCallback: (ad) {},
    ));

    // Rewarded
    AppLovinMAX.setRewardedAdListener(RewardedAdListener(
      onAdLoadedCallback: (ad) {
        _isApplovinRewardedLoaded = true;
      },
      onAdLoadFailedCallback: (adUnitId, error) {
        _isApplovinRewardedLoaded = false;
        Future.delayed(const Duration(seconds: 15), () => _loadApplovinRewarded());
      },
      onAdDisplayedCallback: (ad) {
        _isApplovinRewardedLoaded = false;
      },
      onAdDisplayFailedCallback: (ad, error) {
        _isApplovinRewardedLoaded = false;
        _loadApplovinRewarded();
        if (_applovinRewardedSuccessCallback != null) {
          _showUnityRewarded(
            onRewarded: _applovinRewardedSuccessCallback!,
            onDismissed: _applovinRewardedDismissCallback,
          );
          _applovinRewardedSuccessCallback = null;
          _applovinRewardedDismissCallback = null;
        }
      },
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) {
        _isApplovinRewardedLoaded = false;
        _loadApplovinRewarded();
        _applovinRewardedDismissCallback?.call();
        _applovinRewardedSuccessCallback = null;
        _applovinRewardedDismissCallback = null;
      },
      onAdReceivedRewardCallback: (ad, reward) {
        _applovinRewardedSuccessCallback?.call();
        _applovinRewardedSuccessCallback = null;
      },
      onAdRevenuePaidCallback: (ad) {},
    ));
  }

  // ── AppLovin Loading ──────────────────────────────────────────────────────────
  void _loadApplovinInterstitial() {
    if (!AppConstants.enableAppLovin || !_isApplovinInitialized) return;
    AppLovinMAX.loadInterstitial(AppConstants.applovinInterstitialAdId);
  }

  void _loadApplovinRewarded() {
    if (!AppConstants.enableAppLovin || !_isApplovinInitialized) return;
    AppLovinMAX.loadRewardedAd(AppConstants.applovinRewardedAdId);
  }

  // ── Unity Ads Loading ──────────────────────────────────────────────────────────
  void _loadUnityInterstitial() {
    if (!AppConstants.enableUnityAds || !_isUnityInitialized) return;
    UnityAds.load(
      placementId: AppConstants.unityInterstitialAdId,
      onComplete: (placementId) {
        _isUnityInterstitialLoaded = true;
      },
      onFailed: (placementId, error, message) {
        _isUnityInterstitialLoaded = false;
        Future.delayed(const Duration(seconds: 25), () => _loadUnityInterstitial());
      },
    );
  }

  void _loadUnityRewarded() {
    if (!AppConstants.enableUnityAds || !_isUnityInitialized) return;
    UnityAds.load(
      placementId: AppConstants.unityRewardedAdId,
      onComplete: (placementId) {
        _isUnityRewardedLoaded = true;
      },
      onFailed: (placementId, error, message) {
        _isUnityRewardedLoaded = false;
        Future.delayed(const Duration(seconds: 25), () => _loadUnityRewarded());
      },
    );
  }

  // ── Compatibility Getters ─────────────────────────────────────────────────────
  BannerAd? get gameBannerAd => null;
  BannerAd? get homeBannerAd => null;
  BannerAd? get bannerAd => null;

  // ── Interstitial Logic (Waterfall) ───────────────────────────────────────────
  Future<void> onLevelComplete(int levelNumber, bool isSpecialLevel) async {
    if (isSpecialLevel) return; // No ads on boss/god levels
    _levelsSinceLastInterstitial++;
    if (_levelsSinceLastInterstitial >= AppConstants.interstitialEveryNLevels) {
      await showInterstitial();
    }
  }

  Future<void> showInterstitial() async {
    final completer = Completer<void>();

    // 1. Try AdMob (Priority 1) if enabled
    if (AppConstants.enableAdMob && _isAdmobInterstitialLoaded && _admobInterstitial != null) {
      _levelsSinceLastInterstitial = 0;
      _admobInterstitial!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isAdmobInterstitialLoaded = false;
          _loadAdmobInterstitial(); // Pre-load next
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isAdmobInterstitialLoaded = false;
          _loadAdmobInterstitial();
          // Fallback to AppLovin (Priority 2)
          _showApplovinInterstitial(completer);
        },
      );
      await _admobInterstitial!.show();
    } else {
      // Fallback to AppLovin (Priority 2)
      _showApplovinInterstitial(completer);
    }

    return completer.future;
  }

  void _showApplovinInterstitial(Completer<void> completer) {
    if (AppConstants.enableAppLovin &&
        _isApplovinInitialized &&
        _isApplovinInterstitialLoaded) {
      _levelsSinceLastInterstitial = 0;
      _applovinInterstitialCompleter = completer;
      AppLovinMAX.showInterstitial(AppConstants.applovinInterstitialAdId);
      return;
    }
    // Fallback to Unity Ads (Priority 3)
    _showUnityInterstitial(completer);
  }

  void _showUnityInterstitial(Completer<void> completer) {
    if (AppConstants.enableUnityAds && _isUnityInitialized && _isUnityInterstitialLoaded) {
      _levelsSinceLastInterstitial = 0;
      UnityAds.showVideoAd(
        placementId: AppConstants.unityInterstitialAdId,
        onComplete: (placementId) {
          _isUnityInterstitialLoaded = false;
          _loadUnityInterstitial();
          if (!completer.isCompleted) completer.complete();
        },
        onFailed: (placementId, error, message) {
          _isUnityInterstitialLoaded = false;
          _loadUnityInterstitial();
          if (!completer.isCompleted) completer.complete();
        },
        onSkipped: (placementId) {
          _isUnityInterstitialLoaded = false;
          _loadUnityInterstitial();
          if (!completer.isCompleted) completer.complete();
        },
      );
    } else {
      if (!completer.isCompleted) completer.complete();
    }
  }

  // ── Rewarded Logic (Waterfall) ────────────────────────────────────────────────
  bool get isRewardedAvailable {
    return (AppConstants.enableAdMob && _isAdmobRewardedLoaded) ||
        (AppConstants.enableAppLovin && _isApplovinRewardedLoaded) ||
        (AppConstants.enableUnityAds && _isUnityRewardedLoaded);
  }

  Future<void> showRewarded({
    required void Function() onRewarded,
    void Function()? onDismissed,
  }) async {
    // 1. Try AdMob (Priority 1) if enabled
    if (AppConstants.enableAdMob && _isAdmobRewardedLoaded && _admobRewarded != null) {
      _admobRewarded!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isAdmobRewardedLoaded = false;
          _loadAdmobRewarded();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isAdmobRewardedLoaded = false;
          _loadAdmobRewarded();
          // Fallback to AppLovin (Priority 2)
          _showApplovinRewarded(onRewarded: onRewarded, onDismissed: onDismissed);
        },
      );
      await _admobRewarded!.show(
        onUserEarnedReward: (_, reward) => onRewarded(),
      );
    } else {
      // Fallback to AppLovin (Priority 2)
      _showApplovinRewarded(onRewarded: onRewarded, onDismissed: onDismissed);
    }
  }

  void _showApplovinRewarded({
    required void Function() onRewarded,
    void Function()? onDismissed,
  }) {
    if (AppConstants.enableAppLovin &&
        _isApplovinInitialized &&
        _isApplovinRewardedLoaded) {
      _applovinRewardedSuccessCallback = onRewarded;
      _applovinRewardedDismissCallback = onDismissed;
      AppLovinMAX.showRewardedAd(AppConstants.applovinRewardedAdId);
      return;
    }
    // Fallback to Unity Ads (Priority 3)
    _showUnityRewarded(onRewarded: onRewarded, onDismissed: onDismissed);
  }

  void _showUnityRewarded({
    required void Function() onRewarded,
    void Function()? onDismissed,
  }) {
    if (AppConstants.enableUnityAds && _isUnityInitialized && _isUnityRewardedLoaded) {
      UnityAds.showVideoAd(
        placementId: AppConstants.unityRewardedAdId,
        onComplete: (placementId) {
          _isUnityRewardedLoaded = false;
          _loadUnityRewarded();
          onRewarded();
        },
        onFailed: (placementId, error, message) {
          _isUnityRewardedLoaded = false;
          _loadUnityRewarded();
          onDismissed?.call();
        },
        onSkipped: (placementId) {
          _isUnityRewardedLoaded = false;
          _loadUnityRewarded();
          onDismissed?.call();
        },
      );
    } else {
      onDismissed?.call();
    }
  }

  void dispose() {
    _admobInterstitial?.dispose();
    _admobRewarded?.dispose();
  }
}
