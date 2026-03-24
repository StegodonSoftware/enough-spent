import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:spending_tracker_app/features/settings/data/hive_settings_repository.dart';

void main() {
  late Box box;
  late HiveSettingsRepository repo;

  setUp(() async {
    await setUpTestHive();
    box = await Hive.openBox('settings');
    repo = HiveSettingsRepository(box);
  });

  tearDown(() async => tearDownTestHive());

  group('primaryCurrency', () {
    test('defaults to USD when no value stored', () {
      expect(repo.getPrimaryCurrency(), 'USD');
    });

    test('round-trips set and get', () {
      repo.setPrimaryCurrency('EUR');
      expect(repo.getPrimaryCurrency(), 'EUR');
    });

    // The key was renamed from 'primaryCurrency' to 'defaultCurrency' for
    // backwards compatibility with data stored before the rename.
    test('stores under defaultCurrency key for backwards compatibility', () {
      repo.setPrimaryCurrency('GBP');
      expect(box.get('defaultCurrency'), 'GBP');
    });
  });

  group('recentCurrencies', () {
    test('defaults to empty list when no value stored', () {
      expect(repo.getRecentCurrencies(), isEmpty);
    });

    test('round-trips save and get', () {
      repo.saveRecentCurrencies(['USD', 'EUR', 'JPY']);
      expect(repo.getRecentCurrencies(), ['USD', 'EUR', 'JPY']);
    });

    test('overwrites previous list', () {
      repo.saveRecentCurrencies(['USD', 'EUR']);
      repo.saveRecentCurrencies(['GBP']);
      expect(repo.getRecentCurrencies(), ['GBP']);
    });
  });

  group('firstDayOfWeek', () {
    test('defaults to Monday (1) when no value stored', () {
      expect(repo.getFirstDayOfWeek(), DateTime.monday);
    });

    test('round-trips set and get', () {
      repo.setFirstDayOfWeek(DateTime.sunday);
      expect(repo.getFirstDayOfWeek(), DateTime.sunday);
    });
  });

  group('onboarded', () {
    test('defaults to false when no value stored', () {
      expect(repo.isOnboarded(), isFalse);
    });

    test('round-trips set and get', () {
      repo.setOnboarded(true);
      expect(repo.isOnboarded(), isTrue);
    });

    test('can be set back to false', () {
      repo.setOnboarded(true);
      repo.setOnboarded(false);
      expect(repo.isOnboarded(), isFalse);
    });
  });

  group('lockedCurrencyCode', () {
    test('defaults to null when no value stored', () {
      expect(repo.getLockedCurrencyCode(), isNull);
    });

    test('round-trips set and get', () {
      repo.setLockedCurrencyCode('JPY');
      expect(repo.getLockedCurrencyCode(), 'JPY');
    });

    test('setting null removes the key from box', () {
      repo.setLockedCurrencyCode('JPY');
      repo.setLockedCurrencyCode(null);

      expect(repo.getLockedCurrencyCode(), isNull);
      // Verify the key is actually deleted, not stored as null
      expect(box.containsKey('lockedCurrencyCode'), isFalse);
    });
  });

  group('conversionInProgress', () {
    test('defaults to false when no value stored', () {
      expect(repo.getConversionInProgress(), isFalse);
    });

    test('round-trips set to true and get', () {
      repo.setConversionInProgress(true);
      expect(repo.getConversionInProgress(), isTrue);
    });

    test('can be cleared back to false', () {
      repo.setConversionInProgress(true);
      repo.setConversionInProgress(false);
      expect(repo.getConversionInProgress(), isFalse);
    });
  });

  group('persistence across instances', () {
    test('data written by one instance is read by another on the same box', () {
      repo.setPrimaryCurrency('AUD');
      repo.setOnboarded(true);
      repo.saveRecentCurrencies(['AUD', 'NZD']);

      // Create a second repo backed by the same box
      final repo2 = HiveSettingsRepository(box);
      expect(repo2.getPrimaryCurrency(), 'AUD');
      expect(repo2.isOnboarded(), isTrue);
      expect(repo2.getRecentCurrencies(), ['AUD', 'NZD']);
    });
  });
}
