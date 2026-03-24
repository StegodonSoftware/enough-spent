import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../ad_config.dart';
import '../ad_service.dart';

/// A widget that displays a banner ad.
///
/// Handles loading, displaying, and disposing of banner ads automatically.
/// Shows nothing while loading or if ads are disabled.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdConfig.adsEnabled) return;

    try {
      _bannerAd = BannerAd(
        adUnitId: AdConfig.bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() => _isLoaded = true);
            }
          },
          onAdFailedToLoad: (ad, error) {
            // Fails silently when offline - widget shows nothing
            debugPrint('Banner ad failed to load: ${error.message}');
            ad.dispose();
          },
        ),
      );

      _bannerAd!.load();
    } catch (e) {
      // Catch any unexpected errors - widget will show nothing
      debugPrint('Banner ad error: $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch dev toggle so banner hides/shows reactively
    final devDisabled = context.select<AdService, bool>(
      (s) => s.devAdsDisabled,
    );

    if (!AdConfig.adsEnabled || devDisabled || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    // Hide banner when keyboard is visible
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
