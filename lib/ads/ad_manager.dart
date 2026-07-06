import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// Central ad orchestrator — manages banner, interstitial, and rewarded ads.
/// Uses a waterfall fallback strategy: AdMob (Priority 1) -> Unity Ads (Priority 2).
/// Each ad network can be toggled on/off dynamically in AppConstants.
class AdManager {
  // ── AdMob state ──────────────────────────────────────────────────────────────
  InterstitialAd? _admobInterstitial;
  bool _isAdmobInterstitialLoaded = false;

  RewardedAd? _admobRewarded;
  bool _isAdmobRewardedLoaded = false;
  int _levelsSinceLastInterstitial = 0;

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

    // 2. Initialize and load Unity Ads if enabled
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
          // Fallback to Unity Ads (Priority 2)
          _showUnityInterstitial(completer);
        },
      );
      await _admobInterstitial!.show();
    } else {
      // Fallback to Unity Ads (Priority 2)
      _showUnityInterstitial(completer);
    }

    return completer.future;
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
          // Fallback to Unity Ads (Priority 2)
          _showUnityRewarded(onRewarded: onRewarded, onDismissed: onDismissed);
        },
      );
      await _admobRewarded!.show(
        onUserEarnedReward: (_, reward) => onRewarded(),
      );
    } else {
      // Fallback to Unity Ads (Priority 2)
      _showUnityRewarded(onRewarded: onRewarded, onDismissed: onDismissed);
    }
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
