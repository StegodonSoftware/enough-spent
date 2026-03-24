import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:spending_tracker_app/features/locations/data/hive_location_repository.dart';
import 'package:spending_tracker_app/features/locations/models/location.dart';

Location _makeLocation({
  String id = 'loc-1',
  String name = 'Coffee Shop',
  String initials = 'CS',
  double? latitude,
  double? longitude,
}) {
  return Location(
    id: id,
    name: name,
    initials: initials,
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  late Box box;
  late HiveLocationRepository repo;

  setUp(() async {
    await setUpTestHive();
    box = await Hive.openBox('locations');
    repo = HiveLocationRepository(box);
  });

  tearDown(() async => tearDownTestHive());

  group('save and getById', () {
    test('round-trips a location through Hive', () {
      final location = _makeLocation(id: 'loc-1', name: 'Office', initials: 'OF');
      repo.save(location);

      final retrieved = repo.getById('loc-1')!;
      expect(retrieved.id, 'loc-1');
      expect(retrieved.name, 'Office');
      expect(retrieved.initials, 'OF');
    });

    test('preserves GPS coordinates', () {
      final location = _makeLocation(
        id: 'loc-1',
        latitude: 51.5074,
        longitude: -0.1278,
      );
      repo.save(location);

      final retrieved = repo.getById('loc-1')!;
      expect(retrieved.latitude, 51.5074);
      expect(retrieved.longitude, -0.1278);
    });

    test('returns null for unknown id', () {
      expect(repo.getById('nonexistent'), isNull);
    });

    test('overwriting same id updates the record', () {
      repo.save(_makeLocation(id: 'loc-1', name: 'Old Name'));
      repo.save(_makeLocation(id: 'loc-1', name: 'New Name'));

      expect(repo.getById('loc-1')!.name, 'New Name');
    });
  });

  group('getAll', () {
    test('returns all saved locations', () {
      repo.save(_makeLocation(id: 'loc-1', name: 'Home'));
      repo.save(_makeLocation(id: 'loc-2', name: 'Work'));

      expect(repo.getAll().length, 2);
    });

    test('skips corrupted entries without throwing', () {
      repo.save(_makeLocation(id: 'loc-1'));
      // Put a corrupted map directly — missing required 'initials' field
      box.put('bad', {'id': 'bad', 'name': 'Broken'});

      final all = repo.getAll();
      expect(all.length, 1);
      expect(all.first.id, 'loc-1');
    });

    test('returns empty list when box is empty', () {
      expect(repo.getAll(), isEmpty);
    });
  });

  group('getByName', () {
    test('finds location by exact name', () {
      repo.save(_makeLocation(id: 'loc-1', name: 'Coffee Shop'));
      expect(repo.getByName('Coffee Shop')?.id, 'loc-1');
    });

    test('is case-insensitive', () {
      repo.save(_makeLocation(id: 'loc-1', name: 'Coffee Shop'));
      expect(repo.getByName('coffee shop')?.id, 'loc-1');
      expect(repo.getByName('COFFEE SHOP')?.id, 'loc-1');
    });

    test('trims whitespace before comparing', () {
      repo.save(_makeLocation(id: 'loc-1', name: 'Coffee Shop'));
      expect(repo.getByName('  Coffee Shop  ')?.id, 'loc-1');
    });

    test('returns null when not found', () {
      repo.save(_makeLocation(id: 'loc-1', name: 'Coffee Shop'));
      expect(repo.getByName('Tea House'), isNull);
    });

    test('returns null when box is empty', () {
      expect(repo.getByName('Anywhere'), isNull);
    });
  });

  group('delete', () {
    test('removes the location', () {
      repo.save(_makeLocation(id: 'loc-1'));
      repo.delete('loc-1');

      expect(repo.getById('loc-1'), isNull);
      expect(repo.getAll(), isEmpty);
    });

    test('no-ops for unknown id', () {
      repo.save(_makeLocation(id: 'loc-1'));
      repo.delete('nonexistent');

      expect(repo.getAll().length, 1);
    });
  });

  group('isEmpty', () {
    test('returns true when no locations saved', () {
      expect(repo.isEmpty(), isTrue);
    });

    test('returns false after saving a location', () {
      repo.save(_makeLocation());
      expect(repo.isEmpty(), isFalse);
    });
  });
}
