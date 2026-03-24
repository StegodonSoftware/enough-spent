/// Immutable currency reference data loaded from assets/data/currencies.json.
/// This is read-only reference data, not user-created, so no timestamps needed.
class Currency {
  final String code;
  final String name;
  final String symbol;
  final int decimals;
  final int numToBasic;

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.numToBasic,
  });

  factory Currency.fromJson(String code, Map<String, dynamic> json) {
    final name = json['name'];
    final symbol = json['symbol'];
    final decimals = json['decimals'];

    if (name == null) {
      throw ArgumentError('Currency.fromJson ($code): missing required field "name"');
    }
    if (symbol == null) {
      throw ArgumentError('Currency.fromJson ($code): missing required field "symbol"');
    }
    if (decimals == null) {
      throw ArgumentError('Currency.fromJson ($code): missing required field "decimals"');
    }

    return Currency(
      code: code,
      name: name as String,
      symbol: symbol as String,
      decimals: decimals as int,
      numToBasic: json['numToBasic'] as int? ?? 1,
    );
  }
}
