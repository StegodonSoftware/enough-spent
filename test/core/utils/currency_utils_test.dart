import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/core/utils/currency_utils.dart';

void main() {
  group('toMinorUnits', () {
    test('converts whole dollars (2 decimals)', () {
      expect(toMinorUnits('10', 2), 1000);
    });

    test('converts with cents', () {
      expect(toMinorUnits('10.50', 2), 1050);
    });

    test('converts zero-decimal currency', () {
      expect(toMinorUnits('1530', 0), 1530);
    });

    test('converts three-decimal currency', () {
      expect(toMinorUnits('1.500', 3), 1500);
    });

    test('rounds fractional minor units', () {
      // 10.555 * 100 = 1055.5 → 1056
      expect(toMinorUnits('10.555', 2), 1056);
    });

    test('handles zero', () {
      expect(toMinorUnits('0', 2), 0);
    });
  });

  group('fromMinorUnits', () {
    test('formats 2-decimal currency', () {
      expect(fromMinorUnits(1050, 2), '10.50');
    });

    test('formats whole amount (2 decimals)', () {
      expect(fromMinorUnits(1000, 2), '10.00');
    });

    test('formats zero-decimal currency', () {
      expect(fromMinorUnits(1530, 0), '1530');
    });

    test('formats three-decimal currency', () {
      expect(fromMinorUnits(1500, 3), '1.500');
    });

    test('formats single cent', () {
      expect(fromMinorUnits(1, 2), '0.01');
    });

    test('formats zero', () {
      expect(fromMinorUnits(0, 2), '0.00');
    });

    test('formats large amounts', () {
      expect(fromMinorUnits(9999999, 2), '99999.99');
    });
  });

  group('round-trip: toMinorUnits → fromMinorUnits', () {
    test('USD 10.50 round-trips correctly', () {
      final minor = toMinorUnits('10.50', 2);
      expect(fromMinorUnits(minor, 2), '10.50');
    });

    test('JPY 1530 round-trips correctly', () {
      final minor = toMinorUnits('1530', 0);
      expect(fromMinorUnits(minor, 0), '1530');
    });

    test('BHD 1.500 round-trips correctly', () {
      final minor = toMinorUnits('1.500', 3);
      expect(fromMinorUnits(minor, 3), '1.500');
    });
  });
}
