import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker_app/features/expenses/models/expense.dart';
import 'package:spending_tracker_app/features/locations/location_controller.dart';
import 'package:spending_tracker_app/features/locations/models/location.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeLocationRepository locationRepo;
  late FakeExpenseRepository expenseRepo;
  late LocationController controller;

  setUp(() {
    locationRepo = FakeLocationRepository();
    expenseRepo = FakeExpenseRepository();
    controller = LocationController(locationRepo, expenseRepo);
  });

  group('addLocation', () {
    test('adds and returns location', () {
      final result = controller.addLocation('Coffee Shop');
      expect(result, isNotNull);
      expect(result!.name, 'Coffee Shop');
      expect(result.initials, 'CS'); // first letter of each word
      expect(controller.all.length, 1);
    });

    test('rejects empty name', () {
      expect(controller.addLocation(''), isNull);
      expect(controller.addLocation('   '), isNull);
    });

    test('rejects name exceeding max length', () {
      final longName = 'x' * (Location.maxNameLength + 1);
      expect(controller.addLocation(longName), isNull);
    });

    test('rejects duplicate name', () {
      controller.addLocation('Coffee Shop');
      expect(controller.addLocation('coffee shop'), isNull);
    });
  });

  group('generateInitials', () {
    test('single word uses first 2 chars', () {
      expect(controller.generateInitials('Starbucks'), 'ST');
    });

    test('multiple words uses first letter of first 2 words', () {
      expect(controller.generateInitials('Coffee Shop'), 'CS');
    });

    test('single char word', () {
      expect(controller.generateInitials('X'), 'X');
    });

    test('adds number suffix for duplicates', () {
      controller.addLocation('Coffee Shop'); // CS
      expect(controller.generateInitials('Cool Store'), 'CS1');
    });
  });

  group('isNameAvailable', () {
    test('returns true for new name', () {
      expect(controller.isNameAvailable('New Place'), isTrue);
    });

    test('returns false for existing name (case-insensitive)', () {
      controller.addLocation('Coffee Shop');
      expect(controller.isNameAvailable('coffee shop'), isFalse);
    });

    test('excludeId allows self-match when editing', () {
      final loc = controller.addLocation('Coffee Shop')!;
      expect(controller.isNameAvailable('Coffee Shop', excludeId: loc.id), isTrue);
    });

    test('returns false for empty name', () {
      expect(controller.isNameAvailable(''), isFalse);
    });
  });

  group('updateLocation', () {
    test('updates name', () {
      final loc = controller.addLocation('Old Name')!;
      final result = controller.updateLocation(loc.id, name: 'New Name');
      expect(result, isTrue);
      expect(controller.get(loc.id)!.name, 'New Name');
    });

    test('rejects duplicate name on update', () {
      controller.addLocation('Place A');
      final locB = controller.addLocation('Place B')!;
      expect(controller.updateLocation(locB.id, name: 'Place A'), isFalse);
    });

    test('returns false for non-existent id', () {
      expect(controller.updateLocation('nonexistent', name: 'X'), isFalse);
    });
  });

  group('deleteLocation', () {
    test('removes location', () {
      final loc = controller.addLocation('Test')!;
      expect(controller.deleteLocation(loc.id), isTrue);
      expect(controller.all, isEmpty);
    });

    test('returns false for non-existent', () {
      expect(controller.deleteLocation('nonexistent'), isFalse);
    });
  });

  group('deleteLocationWithCascade', () {
    test('deletes location and clears from expenses', () {
      final loc = controller.addLocation('Test')!;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        locationId: loc.id,
      ));

      final result = controller.deleteLocationWithCascade(loc.id);
      expect(result, isNotNull);
      expect(result!.affectedCount, 1);
      expect(expenseRepo.getById('e1')!.locationId, isNull);
    });

    test('calls onExpensesModified', () {
      int callCount = 0;
      controller.onExpensesModified = () => callCount++;

      final loc = controller.addLocation('Test')!;
      controller.deleteLocationWithCascade(loc.id);
      expect(callCount, 1);
    });
  });

  group('undoDelete', () {
    test('restores location and expense references', () {
      final loc = controller.addLocation('Test')!;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        locationId: loc.id,
      ));

      final result = controller.deleteLocationWithCascade(loc.id)!;
      controller.undoDelete(result);

      expect(controller.get(loc.id), isNotNull);
      expect(expenseRepo.getById('e1')!.locationId, loc.id);
    });
  });

  group('mergeLocations', () {
    test('moves expenses from source to target', () {
      final source = controller.addLocation('Source')!;
      final target = controller.addLocation('Target')!;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        locationId: source.id,
      ));

      final result = controller.mergeLocations(source.id, target.id);
      expect(result, isNotNull);
      expect(result!.affectedCount, 1);
      expect(expenseRepo.getById('e1')!.locationId, target.id);
      expect(controller.get(source.id), isNull); // source deleted
    });

    test('rejects merging into self', () {
      final loc = controller.addLocation('Test')!;
      expect(controller.mergeLocations(loc.id, loc.id), isNull);
    });
  });

  group('undoMerge', () {
    test('restores source and expense references', () {
      final source = controller.addLocation('Source')!;
      final target = controller.addLocation('Target')!;
      expenseRepo.save(Expense(
        id: 'e1',
        amountMinor: 100,
        date: DateTime.now(),
        currencyCode: 'USD',
        locationId: source.id,
      ));

      final result = controller.mergeLocations(source.id, target.id)!;
      controller.undoMerge(result);

      expect(controller.get(source.id), isNotNull);
      expect(expenseRepo.getById('e1')!.locationId, source.id);
    });
  });

  group('search', () {
    test('filters by name substring', () {
      controller.addLocation('Coffee Shop');
      controller.addLocation('Tea House');
      controller.addLocation('Coffee Bean');

      expect(controller.search('coffee').length, 2);
      expect(controller.search('tea').length, 1);
    });

    test('returns all for empty query', () {
      controller.addLocation('A');
      controller.addLocation('B');
      expect(controller.search('').length, 2);
    });
  });

  group('getTopUsed', () {
    test('returns locations sorted by usage', () {
      final loc1 = controller.addLocation('Place A')!;
      final loc2 = controller.addLocation('Place B')!;

      // loc2 used twice, loc1 used once
      expenseRepo.save(Expense(id: 'e1', amountMinor: 100, date: DateTime.now(), currencyCode: 'USD', locationId: loc1.id));
      expenseRepo.save(Expense(id: 'e2', amountMinor: 100, date: DateTime.now(), currencyCode: 'USD', locationId: loc2.id));
      expenseRepo.save(Expense(id: 'e3', amountMinor: 100, date: DateTime.now(), currencyCode: 'USD', locationId: loc2.id));

      final top = controller.getTopUsed();
      expect(top.first.id, loc2.id);
    });

    test('excludes unused locations', () {
      controller.addLocation('Unused');
      expect(controller.getTopUsed(), isEmpty);
    });

    test('respects limit', () {
      final loc1 = controller.addLocation('A')!;
      final loc2 = controller.addLocation('B')!;
      expenseRepo.save(Expense(id: 'e1', amountMinor: 100, date: DateTime.now(), currencyCode: 'USD', locationId: loc1.id));
      expenseRepo.save(Expense(id: 'e2', amountMinor: 100, date: DateTime.now(), currencyCode: 'USD', locationId: loc2.id));

      expect(controller.getTopUsed(limit: 1).length, 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Edge cases
  // ─────────────────────────────────────────────────────────────────────────

  group('get edge cases', () {
    test('get returns null for empty string id', () {
      expect(controller.get(''), isNull);
    });

    test('getByName returns null for empty string', () {
      expect(controller.getByName(''), isNull);
    });

    test('getByName is case-insensitive', () {
      controller.addLocation('Coffee Shop');
      expect(controller.getByName('COFFEE SHOP'), isNotNull);
      expect(controller.getByName('coffee shop'), isNotNull);
    });

    test('getByName returns null for unknown name', () {
      expect(controller.getByName('Nonexistent'), isNull);
    });
  });

  group('addLocation with coordinates', () {
    test('stores latitude and longitude', () {
      final loc = controller.addLocation(
        'Office',
        latitude: 51.5074,
        longitude: -0.1278,
      );
      expect(loc, isNotNull);
      expect(loc!.latitude, 51.5074);
      expect(loc.longitude, -0.1278);
    });
  });

  group('updateLocation coordinates', () {
    test('updates coordinates', () {
      final loc = controller.addLocation('Office')!;
      controller.updateLocation(
        loc.id,
        latitude: 40.7128,
        longitude: -74.0060,
      );
      final updated = controller.get(loc.id)!;
      expect(updated.latitude, 40.7128);
      expect(updated.longitude, -74.0060);
    });

    test('clears coordinates', () {
      final loc = controller.addLocation(
        'Office',
        latitude: 51.5074,
        longitude: -0.1278,
      )!;
      controller.updateLocation(loc.id, clearCoordinates: true);
      final updated = controller.get(loc.id)!;
      expect(updated.latitude, isNull);
      expect(updated.longitude, isNull);
    });

    test('regenerates initials when name changes', () {
      final loc = controller.addLocation('Coffee Shop')!;
      expect(loc.initials, 'CS');

      controller.updateLocation(loc.id, name: 'Tea House');
      final updated = controller.get(loc.id)!;
      expect(updated.initials, 'TH');
    });

    test('rejects empty name on update', () {
      final loc = controller.addLocation('Test')!;
      expect(controller.updateLocation(loc.id, name: ''), isFalse);
    });

    test('rejects name exceeding max length on update', () {
      final loc = controller.addLocation('Test')!;
      final longName = 'x' * (Location.maxNameLength + 1);
      expect(controller.updateLocation(loc.id, name: longName), isFalse);
    });
  });

  group('generateInitials edge cases', () {
    test('unicode characters handled', () {
      // Should take first 2 chars of single word
      expect(controller.generateInitials('Café'), 'CA');
    });

    test('multiple spaces between words', () {
      expect(controller.generateInitials('Coffee   Shop'), 'CS');
    });

    test('three-word name uses first two words', () {
      expect(controller.generateInitials('New York City'), 'NY');
    });

    test('multiple duplicate initials get incrementing numbers', () {
      controller.addLocation('Coffee Shop'); // CS
      controller.addLocation('Cool Store');  // CS1
      expect(controller.generateInitials('Candy Store'), 'CS2');
    });
  });

  group('usageCount', () {
    test('returns correct count', () {
      final loc = controller.addLocation('Test')!;
      expenseRepo.save(Expense(id: 'e1', amountMinor: 100, date: DateTime.now(), currencyCode: 'USD', locationId: loc.id));
      expenseRepo.save(Expense(id: 'e2', amountMinor: 200, date: DateTime.now(), currencyCode: 'USD', locationId: loc.id));
      expect(controller.usageCount(loc.id), 2);
    });

    test('returns zero for unused location', () {
      final loc = controller.addLocation('Unused')!;
      expect(controller.usageCount(loc.id), 0);
    });
  });

  group('mergeLocations edge cases', () {
    test('returns null when source does not exist', () {
      final target = controller.addLocation('Target')!;
      expect(controller.mergeLocations('nonexistent', target.id), isNull);
    });

    test('returns null when target does not exist', () {
      final source = controller.addLocation('Source')!;
      expect(controller.mergeLocations(source.id, 'nonexistent'), isNull);
    });

    test('calls onExpensesModified on merge', () {
      int callCount = 0;
      controller.onExpensesModified = () => callCount++;

      final source = controller.addLocation('Source')!;
      final target = controller.addLocation('Target')!;
      controller.mergeLocations(source.id, target.id);
      expect(callCount, 1);
    });
  });

  group('deleteLocationWithCascade edge cases', () {
    test('returns null for non-existent location', () {
      expect(controller.deleteLocationWithCascade('nonexistent'), isNull);
    });

    test('handles location with no expenses', () {
      final loc = controller.addLocation('Empty')!;
      final result = controller.deleteLocationWithCascade(loc.id);
      expect(result, isNotNull);
      expect(result!.affectedCount, 0);
      expect(controller.get(loc.id), isNull);
    });
  });

  group('undoDelete edge cases', () {
    test('calls onExpensesModified on undo', () {
      int callCount = 0;
      controller.onExpensesModified = () => callCount++;

      final loc = controller.addLocation('Test')!;
      final result = controller.deleteLocationWithCascade(loc.id)!;
      callCount = 0; // reset after delete call

      controller.undoDelete(result);
      expect(callCount, 1);
    });
  });

  group('undoMerge edge cases', () {
    test('calls onExpensesModified on undo', () {
      int callCount = 0;
      controller.onExpensesModified = () => callCount++;

      final source = controller.addLocation('Source')!;
      final target = controller.addLocation('Target')!;
      final result = controller.mergeLocations(source.id, target.id)!;
      callCount = 0; // reset after merge call

      controller.undoMerge(result);
      expect(callCount, 1);
    });
  });
}
