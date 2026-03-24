/// Immutable exchange rates data with USD as base currency.
/// Rates represent how much of each currency equals 1 USD.
class ExchangeRates {
  /// Base currency code (always USD for this app).
  final String base;

  /// When these rates were fetched/generated.
  final DateTime timestamp;

  /// Map of currency code to rate (1 USD = X units of currency).
  /// Example: {'EUR': 0.84, 'GBP': 0.73, 'JPY': 153.0}
  final Map<String, double> rates;

  /// Source of these rates (cached, remote, bundled, emergency).
  /// Used for debugging and display purposes.
  final String? source;

  const ExchangeRates({
    required this.base,
    required this.timestamp,
    required this.rates,
    this.source,
  });

  /// Returns the rate for converting from USD to the given currency.
  /// Returns null if the currency is not found.
  double? getRate(String currencyCode) => rates[currencyCode];

  /// Returns true if rates exist for the given currency code.
  bool hasRate(String currencyCode) => rates.containsKey(currencyCode);

  /// Age of these rates.
  Duration get age => DateTime.now().difference(timestamp);

  /// Returns true if rates are older than the given duration.
  bool isOlderThan(Duration duration) => age > duration;

  /// Rates older than 24 hours are considered stale.
  bool get isStale => isOlderThan(const Duration(hours: 24));

  /// Number of currencies with rates.
  int get currencyCount => rates.length;

  factory ExchangeRates.fromJson(Map<String, dynamic> json) {
    final base = json['base'];
    final timestamp = json['timestamp'];
    final rates = json['rates'];

    if (base == null) {
      throw ArgumentError(
        'ExchangeRates.fromJson: missing required field "base"',
      );
    }
    if (timestamp == null) {
      throw ArgumentError(
        'ExchangeRates.fromJson: missing required field "timestamp"',
      );
    }
    if (rates == null) {
      throw ArgumentError(
        'ExchangeRates.fromJson: missing required field "rates"',
      );
    }

    return ExchangeRates(
      base: base as String,
      timestamp: DateTime.parse(timestamp as String),
      rates: (rates as Map).cast<String, dynamic>().map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base': base,
      'timestamp': timestamp.toIso8601String(),
      'rates': rates,
      if (source != null) 'source': source,
    };
  }
}
