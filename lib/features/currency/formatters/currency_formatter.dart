import '../models/currency.dart';

class CurrencyFormatter {
  static String formatMinor(int amountMinor, Currency currency) {
    final amountMajor = amountMinor / currency.numToBasic;

    return '${currency.symbol} ${amountMajor.toStringAsFixed(currency.decimals)}';
  }
}
