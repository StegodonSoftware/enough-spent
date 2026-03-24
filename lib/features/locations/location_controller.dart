import 'package:flutter/foundation.dart';

import 'data/location_repository.dart';
import 'models/location.dart';
import '../expenses/data/expense_repository.dart';

/// Result of a location deletion with cascade.
class LocationDeleteResult {
  final Location location;
  final List<String> affectedExpenseIds;

  const LocationDeleteResult({
    required this.location,
    required this.affectedExpenseIds,
  });

  int get affectedCount => affectedExpenseIds.length;
}

/// Result of a location merge operation.
class LocationMergeResult {
  final Location sourceLocation;
  final String targetId;
  final List<String> affectedExpenseIds;

  const LocationMergeResult({
    required this.sourceLocation,
    required this.targetId,
    required this.affectedExpenseIds,
  });

  int get affectedCount => affectedExpenseIds.length;
}

class LocationController extends ChangeNotifier {
  final LocationRepository _locations;
  final ExpenseRepository _expenses;
  VoidCallback? onExpensesModified;

  late List<Location> _all;

  LocationController(this._locations, this._expenses, {this.onExpensesModified}) {
    _all = _locations.getAll();
  }

  List<Location> get all => _all.toList();

  /// All locations sorted by usage count descending, then name ascending.
  List<Location> get allSortedByUsage {
    final usageCounts = _expenses.getLocationUsageCounts();
    return _all.toList()..sort((a, b) {
      final diff = (usageCounts[b.id] ?? 0) - (usageCounts[a.id] ?? 0);
      if (diff != 0) return diff;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  /// All locations sorted alphabetically by name.
  List<Location> get allSortedAlphabetically {
    return _all.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// All locations sorted by creation date descending (newest first).
  List<Location> get allSortedByRecentlyAdded {
    return _all.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Returns locations sorted by usage count (most used first).
  /// Optionally limited to top [limit] results.
  List<Location> getTopUsed({int? limit}) {
    final usageCounts = _expenses.getLocationUsageCounts();

    final sorted = _all.toList()
      ..sort((a, b) {
        final countA = usageCounts[a.id] ?? 0;
        final countB = usageCounts[b.id] ?? 0;
        return countB.compareTo(countA);
      });

    // Filter out locations with zero usage
    final used = sorted.where((l) => (usageCounts[l.id] ?? 0) > 0).toList();

    if (limit != null && used.length > limit) {
      return used.sublist(0, limit);
    }
    return used;
  }

  /// Returns locations matching the search query (case-insensitive).
  List<Location> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _all.toList();

    return _all
        .where((l) => l.name.toLowerCase().contains(normalized))
        .toList();
  }

  /// Returns the usage count for a specific location.
  int usageCount(String locationId) {
    return _expenses.countByLocation(locationId);
  }

  Location? get(String id) {
    if (id.isEmpty) return null;
    try {
      return _all.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Location? getByName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try {
      return _all.firstWhere((l) => l.name.trim().toLowerCase() == normalized);
    } catch (_) {
      return null;
    }
  }

  /// Checks if a location name is available (case-insensitive).
  /// Optionally excludes a location by ID (useful when editing).
  bool isNameAvailable(String name, {String? excludeId}) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    return !_all.any(
      (l) => l.name.trim().toLowerCase() == normalized && l.id != excludeId,
    );
  }

  /// Generates unique initials for a location name.
  /// Uses up to 2 letters from the name, then adds numbers if needed.
  /// Examples: "Viet Bistro" -> "VB", second "Viet Bistro" -> "VB1"
  String generateInitials(String name, {String? excludeId}) {
    final baseInitials = _extractBaseInitials(name);
    final existingInitials = _all
        .where((l) => excludeId == null || l.id != excludeId)
        .map((l) => l.initials.toUpperCase())
        .toSet();

    // Try base initials first
    if (!existingInitials.contains(baseInitials.toUpperCase())) {
      return baseInitials;
    }

    // Add numbers until we find a unique one
    var counter = 1;
    while (true) {
      final candidate = '$baseInitials$counter';
      if (!existingInitials.contains(candidate.toUpperCase())) {
        return candidate;
      }
      counter++;

      // Safety limit to prevent infinite loops
      if (counter > 999) {
        throw StateError('Unable to generate unique initials for "$name"');
      }
    }
  }

  /// Extracts base initials from a name (up to 2 letters).
  /// - Single word: first 2 letters (or 1 if single char)
  /// - Multiple words: first letter of first 2 words
  String _extractBaseInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '??';

    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return '??';

    if (words.length == 1) {
      // Single word: take first 2 characters
      final word = words[0];
      if (word.length >= 2) {
        return word.substring(0, 2).toUpperCase();
      }
      return word.toUpperCase();
    }

    // Multiple words: take first letter of first 2 words
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Adds a new location. Returns the created location or null if failed.
  /// Fails if name is empty, too long, or already exists.
  Location? addLocation(String name, {double? latitude, double? longitude}) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) return null;
    if (trimmed.length > Location.maxNameLength) return null;
    if (!isNameAvailable(trimmed)) return null;

    final initials = generateInitials(trimmed);
    final location = Location.create(
      name: trimmed,
      initials: initials,
      latitude: latitude,
      longitude: longitude,
    );

    _locations.save(location);
    _all.add(location);
    notifyListeners();
    return location;
  }

  /// Updates an existing location.
  /// Returns true if successful, false if validation fails.
  bool updateLocation(
    String id, {
    String? name,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    final index = _all.indexWhere((l) => l.id == id);
    if (index == -1) return false;

    final existing = _all[index];
    final newName = name?.trim() ?? existing.name;

    // Validate name if changed
    if (newName != existing.name) {
      if (newName.isEmpty) return false;
      if (newName.length > Location.maxNameLength) return false;
      if (!isNameAvailable(newName, excludeId: id)) return false;
    }

    // Regenerate initials if name changed
    final newInitials = newName != existing.name
        ? generateInitials(newName, excludeId: id)
        : existing.initials;

    final updated = existing.copyWith(
      name: newName,
      initials: newInitials,
      latitude: clearCoordinates ? null : latitude,
      longitude: clearCoordinates ? null : longitude,
      clearLatitude: clearCoordinates,
      clearLongitude: clearCoordinates,
    );

    _locations.save(updated);
    _all[index] = updated;
    notifyListeners();
    return true;
  }

  /// Deletes a location by ID.
  /// Returns true if the location was found and deleted.
  bool deleteLocation(String id) {
    final index = _all.indexWhere((l) => l.id == id);
    if (index == -1) return false;

    _all.removeAt(index);
    _locations.delete(id);
    notifyListeners();
    return true;
  }

  /// Deletes a location and clears it from all expenses that reference it.
  /// Returns the result with the deleted location and affected expense IDs,
  /// or null if the location was not found.
  LocationDeleteResult? deleteLocationWithCascade(String id) {
    final index = _all.indexWhere((l) => l.id == id);
    if (index == -1) return null;

    final location = _all[index];
    final affectedIds = _expenses.clearLocationFromExpenses(id);

    _all.removeAt(index);
    _locations.delete(id);
    onExpensesModified?.call();
    notifyListeners();

    return LocationDeleteResult(
      location: location,
      affectedExpenseIds: affectedIds,
    );
  }

  /// Undoes a location deletion by restoring the location and its expense references.
  void undoDelete(LocationDeleteResult result) {
    _locations.save(result.location);
    _all.add(result.location);
    _expenses.restoreLocationOnExpenses(
      result.affectedExpenseIds,
      result.location.id,
    );
    onExpensesModified?.call();
    notifyListeners();
  }

  /// Merges source location into target location.
  /// All expenses referencing source will be updated to reference target.
  /// The source location is then deleted.
  /// Returns the result with affected data, or null if failed.
  LocationMergeResult? mergeLocations(String sourceId, String targetId) {
    if (sourceId == targetId) return null;

    final sourceIndex = _all.indexWhere((l) => l.id == sourceId);
    final targetIndex = _all.indexWhere((l) => l.id == targetId);
    if (sourceIndex == -1 || targetIndex == -1) return null;

    final sourceLocation = _all[sourceIndex];
    final affectedIds = _expenses.updateLocationOnExpenses(sourceId, targetId);

    _all.removeAt(sourceIndex);
    _locations.delete(sourceId);
    onExpensesModified?.call();
    notifyListeners();

    return LocationMergeResult(
      sourceLocation: sourceLocation,
      targetId: targetId,
      affectedExpenseIds: affectedIds,
    );
  }

  /// Undoes a location merge by restoring the source location and its expense references.
  void undoMerge(LocationMergeResult result) {
    _locations.save(result.sourceLocation);
    _all.add(result.sourceLocation);
    _expenses.restoreLocationOnExpenses(
      result.affectedExpenseIds,
      result.sourceLocation.id,
    );
    onExpensesModified?.call();
    notifyListeners();
  }
}
