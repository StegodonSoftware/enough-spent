import 'package:flutter_test/flutter_test.dart';
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
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('validate', () {
    test('valid location returns no errors', () {
      expect(_makeLocation().validate(), isEmpty);
      expect(_makeLocation().isValid, isTrue);
    });

    test('empty name is invalid', () {
      final loc = _makeLocation(name: '');
      expect(loc.validate(), contains('Name is required'));
    });

    test('whitespace-only name is invalid', () {
      final loc = _makeLocation(name: '   ');
      expect(loc.validate(), contains('Name is required'));
    });

    test('name exceeding max length is invalid', () {
      final longName = 'x' * (Location.maxNameLength + 1);
      final loc = _makeLocation(name: longName);
      expect(loc.validate(), isNotEmpty);
    });

    test('empty initials is invalid', () {
      final loc = _makeLocation(initials: '');
      expect(loc.validate(), contains('Initials are required'));
    });

    test('latitude without longitude is invalid', () {
      final loc = _makeLocation(latitude: 40.0);
      expect(loc.validate(), contains('Both latitude and longitude must be provided together'));
    });

    test('longitude without latitude is invalid', () {
      final loc = _makeLocation(longitude: -74.0);
      expect(loc.validate(), isNotEmpty);
    });

    test('both coordinates provided is valid', () {
      final loc = _makeLocation(latitude: 40.0, longitude: -74.0);
      expect(loc.validate(), isEmpty);
    });

    test('latitude out of range', () {
      final loc = _makeLocation(latitude: 91.0, longitude: 0.0);
      expect(loc.validate(), contains('Latitude must be between -90 and 90'));
    });

    test('longitude out of range', () {
      final loc = _makeLocation(latitude: 0.0, longitude: 181.0);
      expect(loc.validate(), contains('Longitude must be between -180 and 180'));
    });

    test('boundary latitude values are valid', () {
      expect(_makeLocation(latitude: 90.0, longitude: 0.0).validate(), isEmpty);
      expect(_makeLocation(latitude: -90.0, longitude: 0.0).validate(), isEmpty);
    });

    test('boundary longitude values are valid', () {
      expect(_makeLocation(latitude: 0.0, longitude: 180.0).validate(), isEmpty);
      expect(_makeLocation(latitude: 0.0, longitude: -180.0).validate(), isEmpty);
    });
  });

  group('copyWith', () {
    test('overrides name and regenerates updatedAt', () {
      final original = _makeLocation();
      final copy = original.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.id, original.id);
    });

    test('clearLatitude sets latitude to null', () {
      final original = _makeLocation(latitude: 40.0, longitude: -74.0);
      final copy = original.copyWith(clearLatitude: true);
      expect(copy.latitude, isNull);
      expect(copy.longitude, original.longitude);
    });

    test('clearLongitude sets longitude to null', () {
      final original = _makeLocation(latitude: 40.0, longitude: -74.0);
      final copy = original.copyWith(clearLongitude: true);
      expect(copy.longitude, isNull);
    });
  });

  group('toMap / fromMap', () {
    test('round-trips without coordinates', () {
      final original = _makeLocation();
      final map = original.toMap();
      final restored = Location.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.initials, original.initials);
      expect(restored.latitude, isNull);
      expect(restored.longitude, isNull);
    });

    test('round-trips with coordinates', () {
      final original = _makeLocation(latitude: 40.7128, longitude: -74.006);
      final map = original.toMap();
      final restored = Location.fromMap(map);

      expect(restored.latitude, 40.7128);
      expect(restored.longitude, -74.006);
    });

    test('optional coordinates excluded from map when null', () {
      final map = _makeLocation().toMap();
      expect(map.containsKey('latitude'), isFalse);
      expect(map.containsKey('longitude'), isFalse);
    });

    test('throws on missing id', () {
      expect(
        () => Location.fromMap({'name': 'x', 'initials': 'X'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing name', () {
      expect(
        () => Location.fromMap({'id': 'x', 'initials': 'X'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on missing initials', () {
      expect(
        () => Location.fromMap({'id': 'x', 'name': 'Test'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('equality', () {
    test('locations with same id are equal', () {
      final a = _makeLocation(id: 'loc-1', name: 'A');
      final b = _makeLocation(id: 'loc-1', name: 'B');
      expect(a, equals(b));
    });

    test('locations with different id are not equal', () {
      final a = _makeLocation(id: 'loc-1');
      final b = _makeLocation(id: 'loc-2');
      expect(a, isNot(equals(b)));
    });
  });

  group('Location.create', () {
    test('generates a UUID id', () {
      final loc = Location.create(name: 'Test', initials: 'TE');
      expect(loc.id.length, greaterThan(0));
      expect(loc.name, 'Test');
      expect(loc.initials, 'TE');
    });
  });
}
