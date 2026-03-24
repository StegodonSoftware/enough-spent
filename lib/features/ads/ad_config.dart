import 'package:flutter/foundation.dart';

/// Ad unit IDs for Google AdMob.
///
/// Security notes:
/// - Ad unit IDs are NOT secrets - they're public identifiers designed for
///   client-side embedding. Anyone can extract them from a compiled app.
/// - In debug mode, Google's official test IDs are always used (safe for dev).
/// - In release mode, your production IDs are used.
///
/// Setup:
/// 1. Sign up at https://admob.google.com
/// 2. Create your app and ad units
/// 3. Replace the production IDs below with your real IDs
/// 4. Update AndroidManifest.xml and Info.plist with your app IDs
class AdConfig {
  AdConfig._();

  /// Whether ads are enabled.
  /// Returns false on unsupported platforms (desktop, web).
  static bool get adsEnabled {
    // Ads only work on Android and iOS
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    return true;
  }

  /// Number of expenses saved before showing an interstitial.
  static const int interstitialThreshold = 10;

  // ---------------------------------------------------------------------------
  // Test IDs (Google's official test IDs - safe for development)
  // https://developers.google.com/admob/android/test-ads
  // https://developers.google.com/admob/ios/test-ads
  // ---------------------------------------------------------------------------

  static const String _testAndroidBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBannerAdId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  // ---------------------------------------------------------------------------
  // Production IDs (replace with your actual AdMob IDs)
  // ---------------------------------------------------------------------------

  static const String _prodAndroidBanner =
      'ca-app-pub-7952532607371787/8507345551';
  static const String _prodIosBannerIdAdId =
      'ca-app-pub-7952532607371787/3261913840';
  static const String _prodAndroidInterstitial =
      'ca-app-pub-7952532607371787/5988885621';
  static const String _prodIosInterstitial =
      'ca-app-pub-7952532607371787/3255018877';

  // ---------------------------------------------------------------------------
  // Getters (automatically use test IDs in debug, production in release)
  // ---------------------------------------------------------------------------

  /// Banner ad unit ID for the current platform.
  /// Uses test IDs in debug mode, production IDs in release mode.
  static String get bannerAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return kDebugMode ? _testAndroidBanner : _prodAndroidBanner;
      case TargetPlatform.iOS:
        return kDebugMode ? _testIosBannerAdId : _prodIosBannerIdAdId;
      default:
        // Desktop/web - return empty string (ads disabled anyway)
        return '';
    }
  }

  /// Interstitial ad unit ID for the current platform.
  /// Uses test IDs in debug mode, production IDs in release mode.
  static String get interstitialAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return kDebugMode ? _testAndroidInterstitial : _prodAndroidInterstitial;
      case TargetPlatform.iOS:
        return kDebugMode ? _testIosInterstitial : _prodIosInterstitial;
      default:
        // Desktop/web - return empty string (ads disabled anyway)
        return '';
    }
  }
}
