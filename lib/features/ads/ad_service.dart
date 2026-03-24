import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Service for managing Google Mobile Ads.
///
/// Handles initialization, interstitial ad loading/showing, and expense
/// tracking for milestone-based interstitial triggers.
///
/// Designed to work gracefully offline - the app functions normally
/// without network, ads simply won't appear.
class AdService extends ChangeNotifier {
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  int _expensesSinceLastInterstitial = 0;
  Timer? _retryTimer;

  /// Debug-only flag to hide all ads (for screenshots/testing).
  bool _devAdsDisabled = false;

  /// Whether ads are disabled by the developer toggle.
  bool get devAdsDisabled => _devAdsDisabled;

  /// Toggle ads on/off for debug/screenshot purposes.
  void setDevAdsDisabled(bool value) {
    if (_devAdsDisabled == value) return;
    _devAdsDisabled = value;
    notifyListeners();
  }

  /// Whether ads are currently active (platform-enabled and not dev-disabled).
  bool get adsActive => AdConfig.adsEnabled && !_devAdsDisabled;

  /// Delay before retrying ad load after failure (e.g., offline).
  static const Duration _retryDelay = Duration(minutes: 2);

  /// Timeout for SDK initialization to prevent blocking app startup.
  static const Duration _initTimeout = Duration(seconds: 5);

  /// Whether an interstitial ad is loaded and ready to show.
  bool get isInterstitialReady => _isInterstitialReady;

  /// Whether the expense threshold has been reached for showing an interstitial.
  bool get shouldShowInterstitial =>
      _expensesSinceLastInterstitial >= AdConfig.interstitialThreshold;

  /// Initialize the Mobile Ads SDK.
  /// Call this once at app startup.
  ///
  /// Never blocks the app - times out after 5 seconds if offline/slow.
  static Future<void> initialize() async {
    if (!AdConfig.adsEnabled) return;

    try {
      await MobileAds.instance.initialize().timeout(
        _initTimeout,
        onTimeout: () {
          debugPrint('Ad SDK init timed out - app will continue without ads');
          return InitializationStatus({});
        },
      );
    } catch (e) {
      // Silently fail - app works fine without ads
      debugPrint('Ad SDK init failed: $e');
    }
  }

  /// Load an interstitial ad for later use.
  /// Fails silently if offline - will retry later.
  void loadInterstitial() {
    if (!adsActive) return;

    // Cancel any pending retry
    _retryTimer?.cancel();

    try {
      InterstitialAd.load(
        adUnitId: AdConfig.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialReady = true;
            notifyListeners();

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitialAd = null;
                _isInterstitialReady = false;
                notifyListeners();
                // Preload next interstitial
                loadInterstitial();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _interstitialAd = null;
                _isInterstitialReady = false;
                notifyListeners();
                loadInterstitial();
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('Interstitial failed to load: ${error.message}');
            _isInterstitialReady = false;
            notifyListeners();
            // Schedule retry (e.g., user might come back online)
            _scheduleRetry();
          },
        ),
      );
    } catch (e) {
      // Catch any unexpected errors (shouldn't happen, but be safe)
      debugPrint('Interstitial load error: $e');
      _scheduleRetry();
    }
  }

  /// Schedule a retry for loading ads after a delay.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (!_isInterstitialReady) {
        loadInterstitial();
      }
    });
  }

  /// Record that an expense was saved.
  /// Increments the counter toward the interstitial threshold.
  void recordExpenseSaved() {
    if (!adsActive) return;
    _expensesSinceLastInterstitial++;
  }

  /// Show the interstitial ad if one is ready.
  /// Returns true if an ad was shown.
  /// Resets the expense counter after showing the ad.
  Future<bool> showInterstitial() async {
    if (!adsActive) return false;

    if (_isInterstitialReady && _interstitialAd != null) {
      await _interstitialAd!.show();
      _expensesSinceLastInterstitial = 0;
      return true;
    }
    return false;
  }

  /// Try to show an interstitial if the threshold was reached.
  /// Call this when navigating away from quick entry.
  /// Returns true if an ad was shown.
  Future<bool> maybeShowInterstitialOnNavigation() async {
    if (shouldShowInterstitial && _isInterstitialReady) {
      return await showInterstitial();
    }
    return false;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
