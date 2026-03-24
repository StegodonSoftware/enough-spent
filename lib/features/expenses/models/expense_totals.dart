/// The result of comparing two spending values: formatted text and direction.
class SpendingComparison {
  /// Human-readable comparison string (e.g. "↓12% vs last week").
  /// Null when no baseline exists to compare against.
  final String? text;

  /// `true` = spending decreased (good), `false` = increased (bad), `null` = unchanged.
  final bool? isPositive;

  const SpendingComparison({this.text, this.isPositive});
}

/// Tracks amount spent in a specific currency
class CurrencyAmount {
  final String currencyCode;
  final int amountMinor;

  const CurrencyAmount({
    required this.currencyCode,
    required this.amountMinor,
  });
}

/// Helper for building currency breakdown from maps
class CurrencyBreakdownHelper {
  /// Build sorted list from map (descending by amount)
  static List<CurrencyAmount> fromMap(Map<String, int> breakdown) {
    final amounts = breakdown.entries
        .map((e) => CurrencyAmount(currencyCode: e.key, amountMinor: e.value))
        .toList();
    amounts.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return amounts;
  }
}

class DailyTotal {
  final DateTime date;
  final int totalMinor;
  final List<CurrencyAmount> currencyBreakdown;

  const DailyTotal({
    required this.date,
    required this.totalMinor,
    this.currencyBreakdown = const [],
  });
}

class CategoryTotal {
  final String categoryId;
  final String categoryName;
  final int totalMinor;
  final int count;
  final List<CurrencyAmount> currencyBreakdown;

  const CategoryTotal({
    required this.categoryId,
    required this.categoryName,
    required this.totalMinor,
    required this.count,
    this.currencyBreakdown = const [],
  });
}

class LocationTotal {
  final String locationId;
  final String locationName;
  final int totalMinor;
  final int count;
  final List<CurrencyAmount> currencyBreakdown;

  const LocationTotal({
    required this.locationId,
    required this.locationName,
    required this.totalMinor,
    required this.count,
    this.currencyBreakdown = const [],
  });
}
