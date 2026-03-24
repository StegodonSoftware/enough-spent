import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/core/validation/amount_validator.dart';

void main() {
  group('valid inputs', () {
    test('whole number is valid for 2-decimal currency', () {
      expect(validateAmount(input: '10', decimals: 2), isNull);
    });

    test('correct decimal places accepted', () {
      expect(validateAmount(input: '10.99', decimals: 2), isNull);
      expect(validateAmount(input: '10.9', decimals: 2), isNull);
    });

    test('zero-decimal currency accepts whole number', () {
      expect(validateAmount(input: '1500', decimals: 0), isNull);
    });

    test('3-decimal currency accepts up to 3 places', () {
      expect(validateAmount(input: '1.500', decimals: 3), isNull);
      expect(validateAmount(input: '1.5', decimals: 3), isNull);
    });

    test('large amount is valid', () {
      expect(validateAmount(input: '99999.99', decimals: 2), isNull);
    });
  });

  group('empty and whitespace', () {
    test('empty string returns error', () {
      expect(validateAmount(input: '', decimals: 2), isNotNull);
    });

    test('whitespace-only string returns error', () {
      expect(validateAmount(input: '   ', decimals: 2), isNotNull);
    });
  });

  group('non-numeric input', () {
    test('letters return error', () {
      expect(validateAmount(input: 'abc', decimals: 2), isNotNull);
    });

    test('mixed alphanumeric returns error', () {
      expect(validateAmount(input: '12abc', decimals: 2), isNotNull);
    });

    test('currency symbol returns error', () {
      expect(validateAmount(input: '\$10', decimals: 2), isNotNull);
    });
  });

  group('zero and negative', () {
    test('zero returns error', () {
      expect(validateAmount(input: '0', decimals: 2), isNotNull);
    });

    test('0.00 returns error', () {
      expect(validateAmount(input: '0.00', decimals: 2), isNotNull);
    });

    test('negative number returns error', () {
      expect(validateAmount(input: '-5', decimals: 2), isNotNull);
    });

    test('negative decimal returns error', () {
      expect(validateAmount(input: '-0.01', decimals: 2), isNotNull);
    });
  });

  group('decimal place limits', () {
    test('exceeding 2-decimal limit returns error', () {
      expect(validateAmount(input: '10.999', decimals: 2), isNotNull);
    });

    test('exceeding 0-decimal limit returns error', () {
      expect(validateAmount(input: '10.1', decimals: 0), isNotNull);
    });

    test('exceeding 3-decimal limit returns error', () {
      expect(validateAmount(input: '1.0001', decimals: 3), isNotNull);
    });

    test('exactly at limit is valid', () {
      expect(validateAmount(input: '1.00', decimals: 2), isNull);
      expect(validateAmount(input: '1.000', decimals: 3), isNull);
    });
  });
}
