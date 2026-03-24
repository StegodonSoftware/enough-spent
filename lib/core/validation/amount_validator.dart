String? validateAmount({required String input, required int decimals}) {
  if (input.trim().isEmpty) {
    return 'Enter an amount';
  }

  final value = num.tryParse(input);
  if (value == null) {
    return 'Invalid number';
  }

  if (value <= 0) {
    return 'Amount must be greater than zero';
  }

  final parts = input.split('.');
  if (parts.length == 2 && parts[1].length > decimals) {
    return 'Maximum $decimals decimal places allowed';
  }

  return null;
}
