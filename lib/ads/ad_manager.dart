import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:async';
import '../core/constants.dart';
import '../core/app_colors.dart';

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

  // ── On-Demand Loading Helpers for Fallback ────────────────────────────────────
  Future<RewardedAd?> _loadAdmobRewardedOnDemand(Duration timeout) {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: AppConstants.admobRewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    );
  }

  Future<InterstitialAd?> _loadAdmobInterstitialOnDemand(Duration timeout) {
    final completer = Completer<InterstitialAd?>();
    InterstitialAd.load(
      adUnitId: AppConstants.admobInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.setImmersiveMode(true);
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    );
  }

  // ── Rewarded Logic (Waterfall) ────────────────────────────────────────────────
  bool get isRewardedAvailable {
    return AppConstants.enableAdMob || AppConstants.enableUnityAds;
  }

  /// Displays a non-intrusive loading spinner dialog while fetching and preparing the rewarded ad.
  Future<void> showRewardedWithLoader(
    BuildContext context, {
    required void Function() onRewarded,
    void Function()? onDismissed,
  }) async {
    bool loaderOpen = true;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceLight, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Ad...',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    void closeLoader() {
      if (loaderOpen && context.mounted) {
        loaderOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    await showRewarded(
      onAdOpened: closeLoader,
      onRewarded: () {
        closeLoader();
        onRewarded();
      },
      onDismissed: () {
        closeLoader();
        onDismissed?.call();
      },
    );
  }

  /// Shows a rewarded ad with a robust multi-tier fallback mechanism:
  /// 1. Pre-loaded AdMob Rewarded Ad
  /// 2. Fast On-Demand AdMob Rewarded Ad load
  /// 3. Pre-loaded AdMob Interstitial Ad (backup ad for reward)
  /// 4. Fast On-Demand AdMob Interstitial Ad load
  /// 5. Unity Rewarded / Interstitial Ads (if enabled)
  /// 6. Direct reward fallback if ad network inventory is unavailable
  Future<void> showRewarded({
    required void Function() onRewarded,
    void Function()? onDismissed,
    void Function()? onAdOpened,
  }) async {
    void handleSuccess() {
      onRewarded();
    }

    void handleFinish() {
      onDismissed?.call();
    }

    // Tier 1: Pre-loaded AdMob Rewarded Ad
    if (AppConstants.enableAdMob && _isAdmobRewardedLoaded && _admobRewarded != null) {
      final ad = _admobRewarded!;
      _admobRewarded = null;
      _isAdmobRewardedLoaded = false;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          onAdOpened?.call();
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadAdmobRewarded();
          handleFinish();
        },
        onAdFailedToShowFullScreenContent: (ad, error) async {
          ad.dispose();
          _loadAdmobRewarded();
          await _showRewardedFallback(handleSuccess: handleSuccess, handleFinish: handleFinish, onAdOpened: onAdOpened);
        },
      );

      await ad.show(
        onUserEarnedReward: (_, reward) {
          handleSuccess();
        },
      );
      return;
    }

    // Tier 2: Try fast on-demand load of AdMob Rewarded Ad (up to 3 seconds)
    if (AppConstants.enableAdMob) {
      final onDemandAd = await _loadAdmobRewardedOnDemand(const Duration(seconds: 3));
      if (onDemandAd != null) {
        onDemandAd.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (ad) {
            onAdOpened?.call();
          },
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _loadAdmobRewarded();
            handleFinish();
          },
          onAdFailedToShowFullScreenContent: (ad, error) async {
            ad.dispose();
            _loadAdmobRewarded();
            await _showRewardedFallback(handleSuccess: handleSuccess, handleFinish: handleFinish, onAdOpened: onAdOpened);
          },
        );

        await onDemandAd.show(
          onUserEarnedReward: (_, reward) {
            handleSuccess();
          },
        );
        return;
      }
    }

    // Tier 3 & beyond: Fallback cascade
    await _showRewardedFallback(handleSuccess: handleSuccess, handleFinish: handleFinish, onAdOpened: onAdOpened);
  }

  Future<void> _showRewardedFallback({
    required VoidCallback handleSuccess,
    required VoidCallback handleFinish,
    VoidCallback? onAdOpened,
  }) async {
    // Fallback 1: Pre-loaded AdMob Interstitial
    if (AppConstants.enableAdMob && _isAdmobInterstitialLoaded && _admobInterstitial != null) {
      final ad = _admobInterstitial!;
      _admobInterstitial = null;
      _isAdmobInterstitialLoaded = false;
      _levelsSinceLastInterstitial = 0;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          onAdOpened?.call();
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadAdmobInterstitial();
          handleSuccess(); // Grant reward since user watched fallback ad!
          handleFinish();
        },
        onAdFailedToShowFullScreenContent: (ad, error) async {
          ad.dispose();
          _loadAdmobInterstitial();
          await _showUnityOrDirectFallback(handleSuccess: handleSuccess, handleFinish: handleFinish, onAdOpened: onAdOpened);
        },
      );

      await ad.show();
      return;
    }

    // Fallback 2: Fast On-demand AdMob Interstitial
    if (AppConstants.enableAdMob) {
      final onDemandInter = await _loadAdmobInterstitialOnDemand(const Duration(seconds: 3));
      if (onDemandInter != null) {
        onDemandInter.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (ad) {
            onAdOpened?.call();
          },
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _loadAdmobInterstitial();
            handleSuccess();
            handleFinish();
          },
          onAdFailedToShowFullScreenContent: (ad, error) async {
            ad.dispose();
            _loadAdmobInterstitial();
            await _showUnityOrDirectFallback(handleSuccess: handleSuccess, handleFinish: handleFinish, onAdOpened: onAdOpened);
          },
        );

        await onDemandInter.show();
        return;
      }
    }

    // Fallback 3: Unity Ads / Direct Reward
    await _showUnityOrDirectFallback(handleSuccess: handleSuccess, handleFinish: handleFinish, onAdOpened: onAdOpened);
  }

  Future<void> _showUnityOrDirectFallback({
    required VoidCallback handleSuccess,
    required VoidCallback handleFinish,
    VoidCallback? onAdOpened,
  }) async {
    if (AppConstants.enableUnityAds && _isUnityInitialized && _isUnityRewardedLoaded) {
      onAdOpened?.call();
      _showUnityRewarded(
        onRewarded: () {
          handleSuccess();
          handleFinish();
        },
        onDismissed: handleFinish,
      );
      return;
    }

    // Final Fallback: Network/Ad Inventory failed — grant reward so 2x button always works for user!
    debugPrint('AdMob & Unity ads unavailable. Granting reward fallback.');
    onAdOpened?.call();
    handleSuccess();
    handleFinish();
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
