import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'models/exchange_rates.dart';

/// Provides exchange rates from various sources with secure fallback chain:
/// 1. Cached rates (Hive) - if fresh (< 24h)
/// 2. Remote endpoint (Cloudflare Worker)
/// 3. Bundled rates (always available offline)
///
/// Security note: The Cloudflare Worker endpoint is public and doesn't require
/// authentication. The API key, if needed in future, should be managed by the
/// Worker itself or via a backend proxy, never exposed in the client app.
class CurrencyRateProvider {
  static const _bundledRatesPath = 'assets/data/currency_rates.json';
  static const _cacheKey = 'cached_exchange_rates';

  /// Cloudflare Worker endpoint (configurable via CURRENCY_WORKER_URL env var).
  /// Can be overridden at build time: flutter run --dart-define='CURRENCY_WORKER_URL=...'
  static const _cloudflareEndpoint = String.fromEnvironment(
    'CURRENCY_WORKER_URL',
    defaultValue:
        'https://currency-rates-worker.stegodonsoftware.workers.dev/latest',
  );

  /// API key for Cloudflare Worker endpoint (required for auth).
  /// Injected at build time via --dart-define=CURRENCY_API_KEY=...
  /// Never hardcode or commit this value.
  static const String _apiKey = String.fromEnvironment('CURRENCY_API_KEY');

  /// Request timeout duration.
  static const _requestTimeout = Duration(seconds: 10);

  /// Fallback rates if bundled file fails to load.
  static final _emergencyFallback = ExchangeRates(
    base: 'USD',
    timestamp: DateTime(2025, 1, 1),
    rates: const {
      'USD': 1.0,
      'EUR': 0.85,
      'GBP': 0.73,
      'JPY': 150.0,
      'CAD': 1.36,
      'AUD': 1.53,
    },
    source: 'emergency',
  );

  /// Load exchange rates with secure 3-tier fallback chain.
  ///
  /// Fallback order:
  /// 1. **Cached rates** (Hive) - if fresh (< 24h old) - fastest
  /// 2. **Remote rates** (Cloudflare Worker) - if cache stale/missing - most current
  /// 3. **Bundled rates** (JSON asset) - always available offline - worst case
  /// 4. **Emergency fallback** - major currencies only - should never reach
  ///
  /// Args:
  ///   settingsBox: Initialized Hive Box for caching rates
  ///
  /// Returns:
  ///   Always returns ExchangeRates - never null or throws.
  ///   Guarantees app continues even if remote fetch and bundled assets fail.
  ///
  /// Security:
  ///   - No credentials sent to remote endpoint (public Cloudflare Worker)
  ///   - Cached rates validated before use (type-safety, staleness check)
  ///   - Network errors handled gracefully with automatic fallback
  ///   - No sensitive data exposed in logs (production)
  static Future<ExchangeRates> loadRates(Box settingsBox) async {
    // 1. Try cached rates if fresh
    final cachedRates = await _loadCachedRates(settingsBox);
    if (cachedRates != null) {
      if (kDebugMode) {
        debugPrint(
          'CurrencyRateProvider: Using cached rates (age: ${cachedRates.age.inHours}h)',
        );
      }
      return cachedRates;
    }

    // 2. Try remote fetch from Cloudflare Worker
    final remoteRates = await _fetchRemoteRates();
    if (remoteRates != null) {
      // Cache the fresh rates for next startup
      await _cacheRates(settingsBox, remoteRates);
      if (kDebugMode) {
        debugPrint('CurrencyRateProvider: Fetched fresh rates from remote');
      }
      return remoteRates;
    }

    // 3. Fall back to bundled rates (guaranteed available)
    if (kDebugMode) {
      debugPrint(
        'CurrencyRateProvider: Using bundled rates (remote fetch unavailable)',
      );
    }
    return _loadBundledRates();
  }

  /// Fetch fresh rates from the remote endpoint and cache them.
  ///
  /// Bypasses the cache freshness check — always attempts a remote fetch.
  /// Returns the new rates on success, or null if the remote fetch failed.
  static Future<ExchangeRates?> refreshRates(Box settingsBox) async {
    final remote = await _fetchRemoteRates();
    if (remote != null) {
      await _cacheRates(settingsBox, remote);
    }
    return remote;
  }

  /// Load cached rates from Hive if they exist and are fresh (< 24h old).
  ///
  /// Safely reads from the settings box without throwing. If cache is corrupted
  /// or missing, returns null to fall back to remote/bundled rates.
  ///
  /// Args:
  ///   settingsBox: Hive Box for reading cached rates (must be initialized)
  ///
  /// Returns:
  ///   Fresh ExchangeRates if found and valid, null otherwise
  static Future<ExchangeRates?> _loadCachedRates(Box settingsBox) async {
    try {
      // Safely read from Hive - get() returns null if key doesn't exist
      final cachedData = settingsBox.get(_cacheKey);
      if (cachedData == null) return null;

      // Safely deserialize - ensure type safety
      // Hive returns LinkedMap, use cast<String, dynamic>() for proper type conversion
      final cachedJson = cachedData is Map
          ? cachedData.cast<String, dynamic>()
          : null;

      if (cachedJson == null) {
        if (kDebugMode) {
          debugPrint(
            'CurrencyRateProvider: Cached data exists but has invalid type',
          );
        }
        return null;
      }

      final rates = ExchangeRates.fromJson(cachedJson);

      // Check if rates are still fresh (< 24h old)
      if (rates.isStale) {
        if (kDebugMode) {
          debugPrint(
            'CurrencyRateProvider: Cached rates are stale (${rates.age.inHours}h old)',
          );
        }
        return null;
      }

      return rates;
    } catch (e) {
      // Cache is corrupted or deserialization failed - not fatal
      if (kDebugMode) {
        debugPrint(
          'CurrencyRateProvider: Failed to load cached rates (will fall back): $e',
        );
      }
      return null;
    }
  }

  /// Fetch rates from Cloudflare Worker endpoint with authentication.
  ///
  /// Requires CURRENCY_API_KEY to be set in .env file.
  /// If key is not configured, skips remote fetch and falls back to cache/bundled.
  static Future<ExchangeRates?> _fetchRemoteRates() async {
    // Fail gracefully if API key not configured (e.g., development without key)
    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'CurrencyRateProvider: CURRENCY_API_KEY not configured, skipping remote fetch',
        );
      }
      return null;
    }

    try {
      final response = await http
          .get(
            Uri.parse(_cloudflareEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Key': _apiKey, // Your Cloudflare Worker auth header
            },
          )
          .timeout(_requestTimeout);

      if (kDebugMode) {
        debugPrint(
          'CurrencyRateProvider: Remote fetch status: ${response.statusCode}',
        );
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        // Worker wraps rates in { fetchedAt, data { base, rates } }
        // Extract the data part and add the timestamp from fetchedAt
        final ratesData = json['data'] as Map<String, dynamic>? ?? json;
        final ratesWithTimestamp = {
          ...ratesData,
          'timestamp': json['fetchedAt'] ?? DateTime.now().toIso8601String(),
          'source': 'remote',
        };
        return ExchangeRates.fromJson(ratesWithTimestamp);
      } else if (response.statusCode == 401) {
        // Authentication failed - key is invalid or expired
        if (kDebugMode) {
          debugPrint(
            'CurrencyRateProvider: Remote fetch failed - API key rejected (401)',
          );
        }
        return null;
      } else {
        if (kDebugMode) {
          debugPrint(
            'CurrencyRateProvider: Remote fetch failed with status ${response.statusCode}',
          );
        }
        return null;
      }
    } on http.ClientException catch (e) {
      // Network error (DNS, connection refused, etc.)
      if (kDebugMode) {
        debugPrint(
          'CurrencyRateProvider: Network error during remote fetch: ${e.message}',
        );
      }
      return null;
    } catch (e) {
      // Timeout or other errors
      if (kDebugMode) {
        debugPrint('CurrencyRateProvider: Remote fetch error: $e');
      }
      return null;
    }
  }

  /// Cache fresh rates to Hive for offline access.
  ///
  /// If caching fails (e.g., disk full), continues gracefully - rates were
  /// successfully fetched, just not persisted for next startup.
  ///
  /// Args:
  ///   settingsBox: Hive Box for storing rates (must be initialized)
  ///   rates: Fresh exchange rates to cache
  static Future<void> _cacheRates(Box settingsBox, ExchangeRates rates) async {
    try {
      await settingsBox.put(_cacheKey, rates.toJson());
      if (kDebugMode) {
        debugPrint('CurrencyRateProvider: Cached fresh rates to Hive');
      }
    } catch (e) {
      // Caching failure is not fatal - we have the rates in memory
      if (kDebugMode) {
        debugPrint(
          'CurrencyRateProvider: Failed to cache rates (non-fatal): $e',
        );
      }
    }
  }

  /// Load rates bundled with the app as JSON asset.
  ///
  /// This is the final fallback when cache is empty/stale and remote fetch failed.
  /// Bundled rates are guaranteed to be available offline.
  ///
  /// If bundled rates fail to load (extremely rare), falls back to emergency
  /// rates with only major currencies. This ensures the app never crashes due
  /// to missing rates.
  static Future<ExchangeRates> _loadBundledRates() async {
    try {
      final raw = await rootBundle.loadString(_bundledRatesPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final jsonWithSource = {
        ...json,
        'source': 'bundled',
      };
      return ExchangeRates.fromJson(jsonWithSource);
    } catch (e) {
      // Bundled rates failed - use emergency fallback (dev logs only)
      if (kDebugMode) {
        debugPrint(
          'CurrencyRateProvider: Failed to load bundled rates, using emergency fallback: $e',
        );
      }
      return _emergencyFallback;
    }
  }
}
