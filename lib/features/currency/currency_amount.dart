import 'models/currency.dart';

class CurrencyAmountResult {
  final int? minorUnits;
  final String? error;

  const CurrencyAmountResult.success(this.minorUnits) : error = null;
  const CurrencyAmountResult.failure(this.error) : minorUnits = null;

  bool get isValid => minorUnits != null;
}

CurrencyAmountResult parseCurrencyAmount(String input, Currency currency) {
  final normalized = input.replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed.isNaN || parsed < 0) {
    return const CurrencyAmountResult.failure('Invalid amount');
  }

  final minor = (parsed * currency.numToBasic).round();
  return CurrencyAmountResult.success(minor);
}
