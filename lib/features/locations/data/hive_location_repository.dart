import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/location.dart';
import 'location_repository.dart';

class HiveLocationRepository implements LocationRepository {
  final Box _box;

  HiveLocationRepository(this._box);

  @override
  List<Location> getAll() {
    final locations = <Location>[];
    for (final entry in _box.values) {
      try {
        locations.add(Location.fromMap(Map.from(entry)));
      } catch (e) {
        debugPrint('HiveLocationRepository: skipping corrupted location entry: $e');
      }
    }
    return locations;
  }

  @override
  Location? getById(String id) {
    final data = _box.get(id);
    if (data == null) return null;
    return Location.fromMap(Map.from(data));
  }

  @override
  Location? getByName(String name) {
    final normalizedName = name.trim().toLowerCase();
    for (final entry in _box.values) {
      try {
        final entryName = (entry['name'] as String).trim().toLowerCase();
        if (entryName == normalizedName) {
          return Location.fromMap(Map.from(entry));
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  void save(Location location) {
    _box.put(location.id, location.toMap());
  }

  @override
  void delete(String id) {
    _box.delete(id);
  }

  @override
  bool isEmpty() => _box.isEmpty;
}
