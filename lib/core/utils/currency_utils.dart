import 'dart:math';

int toMinorUnits(String input, int decimals) {
  final factor = pow(10, decimals);
  return (double.parse(input) * factor).round();
}

String fromMinorUnits(int minorUnits, int decimals) {
  final factor = pow(10, decimals);
  final value = minorUnits / factor;
  return value.toStringAsFixed(decimals);
}
