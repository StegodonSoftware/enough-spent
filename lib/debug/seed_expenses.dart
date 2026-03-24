import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../features/categories/category_controller.dart';
import '../features/categories/models/expense_category.dart';
import '../features/expenses/models/expense.dart';
import '../features/expenses/expense_controller.dart';
import '../features/locations/location_controller.dart';

/// Sample locations to create for testing.
/// Each entry is (name, typical categories it pairs with).
const _sampleLocations = [
  ('Grocery Mart', ['Food', 'Shopping']),
  ('Corner Coffee', ['Food']),
  ('City Gas Station', ['Transport']),
  ('Downtown Pharmacy', ['Health']),
  ('Metro Cinema', ['Entertainment']),
  ('Quick Burger', ['Food']),
  ('Home Depot', ['Shopping', 'Bills']),
  ('Thai Palace', ['Food']),
];

/// Sample notes for expenses.
const _sampleNotes = [
  'Weekly groceries',
  'Morning coffee',
  'Lunch with coworkers',
  'Gas fill-up',
  'Medicine',
  'Movie night',
  'Home supplies',
  'Dinner out',
  'Snacks',
  'Quick errand',
  'Birthday gift',
  'Subscription renewal',
];

/// Ensures sample locations exist, creating them if needed.
/// Returns a map of location name -> location ID for use in seeding.
Map<String, String> _ensureSampleLocations(LocationController locationController) {
  final locationMap = <String, String>{};

  for (final (name, _) in _sampleLocations) {
    final existing = locationController.getByName(name) ??
        locationController.addLocation(name);
    if (existing != null) {
      locationMap[name] = existing.id;
    }
  }

  return locationMap;
}

/// Adds sample expenses with realistic distribution.
/// Call this from developer tools button.
void addSampleExpenses({
  required ExpenseController expenseController,
  required CategoryController categoryController,
  required LocationController locationController,
  int count = 25,
  int daysRange = 60,
}) {
  if (!kDebugMode) return;

  final locationMap = _ensureSampleLocations(locationController);
  final now = DateTime.now();
  final rng = Random();

  // Build list of (locationName, locationId, preferredCategories)
  final locationsWithIds = <(String, String, List<String>)>[];
  for (final (name, categories) in _sampleLocations) {
    final id = locationMap[name];
    if (id != null) {
      locationsWithIds.add((name, id, categories));
    }
  }

  for (int i = 0; i < count; i++) {
    final id = const Uuid().v4();

    // Random date within range, weighted toward recent dates
    final daysAgo = _weightedRandomDays(rng, daysRange);
    final date = now.subtract(Duration(days: daysAgo));

    // ~60% have a location
    String? locationId;
    String? categoryId;

    if (rng.nextDouble() < 0.6 && locationsWithIds.isNotEmpty) {
      final locationData = locationsWithIds[rng.nextInt(locationsWithIds.length)];
      locationId = locationData.$2;
      final preferredCategories = locationData.$3;

      // Use a preferred category for this location 70% of the time
      if (rng.nextDouble() < 0.7 && preferredCategories.isNotEmpty) {
        final categoryName = preferredCategories[rng.nextInt(preferredCategories.length)];
        categoryId = categoryController.getByName(categoryName)?.id;
      }
    }

    // If no category yet, pick random (or leave uncategorized ~15% of time)
    if (categoryId == null && rng.nextDouble() > 0.15) {
      final categoryName = defaultCategoryNames[rng.nextInt(defaultCategoryNames.length)];
      categoryId = categoryController.getByName(categoryName)?.id;
    }

    // ~30% have notes
    String? note;
    if (rng.nextDouble() < 0.3) {
      note = _sampleNotes[rng.nextInt(_sampleNotes.length)];
    }

    // Amount: mostly small purchases, occasional larger ones
    final amountMinor = _weightedRandomAmount(rng);

    expenseController.add(
      Expense(
        id: id,
        amountMinor: amountMinor,
        currencyCode: 'USD',
        categoryId: categoryId,
        locationId: locationId,
        date: date,
        note: note,
      ),
    );
  }
}

/// Generates days ago with bias toward recent dates.
/// More expenses in the last 2 weeks, fewer further back.
int _weightedRandomDays(Random rng, int maxDays) {
  final weight = rng.nextDouble();
  if (weight < 0.4) {
    // 40% within last 7 days
    return rng.nextInt(7);
  } else if (weight < 0.7) {
    // 30% within 7-14 days
    return 7 + rng.nextInt(7);
  } else {
    // 30% within 14-maxDays
    return 14 + rng.nextInt(maxDays - 14);
  }
}

/// Generates amount with realistic distribution.
/// Many small purchases, fewer medium, rare large ones.
int _weightedRandomAmount(Random rng) {
  final weight = rng.nextDouble();
  if (weight < 0.5) {
    // 50%: small purchases $1-15
    return 100 + rng.nextInt(1400);
  } else if (weight < 0.8) {
    // 30%: medium purchases $15-50
    return 1500 + rng.nextInt(3500);
  } else if (weight < 0.95) {
    // 15%: larger purchases $50-150
    return 5000 + rng.nextInt(10000);
  } else {
    // 5%: big purchases $150-300
    return 15000 + rng.nextInt(15000);
  }
}
