import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:applovin_max/applovin_max.dart';
import '../core/constants.dart';

class UnifiedBannerAd extends StatefulWidget {
  final String admobUnitId;
  final String applovinUnitId;
  final String unityPlacementId;

  const UnifiedBannerAd({
    super.key,
    required this.admobUnitId,
    required this.applovinUnitId,
    required this.unityPlacementId,
  });

  @override
  State<UnifiedBannerAd> createState() => _UnifiedBannerAdState();
}

class _UnifiedBannerAdState extends State<UnifiedBannerAd> {
  BannerAd? _admobBanner;
  bool _admobLoaded = false;
  bool _admobFailed = false;
  bool _applovinFailed = false;

  @override
  void initState() {
    super.initState();
    if (AppConstants.enableAdMob) {
      _loadAdmobBanner();
    } else {
      _admobFailed = true;
    }
  }

  void _loadAdmobBanner() {
    _admobBanner = BannerAd(
      adUnitId: widget.admobUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _admobLoaded = true;
              _admobFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _admobLoaded = false;
              _admobFailed = true;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _admobBanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. AdMob (Priority 1)
    if (AppConstants.enableAdMob) {
      if (_admobLoaded && _admobBanner != null) {
        return SizedBox(
          width: 320,
          height: 50,
          child: AdWidget(ad: _admobBanner!),
        );
      } else if (!_admobFailed) {
        // Loading state
        return const SizedBox(
          width: 320,
          height: 50,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
    }

    // 2. AppLovin (Priority 2)
    if (AppConstants.enableAppLovin && !_applovinFailed) {
      return SizedBox(
        width: 320,
        height: 50,
        child: MaxAdView(
          adUnitId: widget.applovinUnitId,
          adFormat: AdFormat.banner,
          listener: AdViewAdListener(
            onAdLoadedCallback: (ad) {
              debugPrint("AppLovin Banner loaded");
            },
            onAdLoadFailedCallback: (adUnitId, error) {
              debugPrint("AppLovin Banner failed to load: $error");
              if (mounted) {
                setState(() {
                  _applovinFailed = true;
                });
              }
            },
          ),
        ),
      );
    }

    // 3. Unity Ads (Priority 3)
    if (AppConstants.enableUnityAds) {
      return SizedBox(
        width: 320,
        height: 50,
        child: UnityBannerAd(
          placementId: widget.unityPlacementId,
          onFailed: (placementId, error, message) {
            debugPrint('Unity Banner failed: $error - $message');
          },
        ),
      );
    }

    // If no ad network is active or all failed
    return const SizedBox(height: 50);
  }
}
