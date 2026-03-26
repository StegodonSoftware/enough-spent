import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/currency/currency_rate_provider.dart';
import 'core/storage/hive_encryption.dart';
import 'core/currency/currency_service.dart';
import 'core/currency/primary_currency_converter.dart';
import 'features/ads/ad_service.dart';
import 'features/currency/data/currency_registry.dart';
import 'features/expenses/data/hive_expense_repository.dart';
import 'features/expenses/data/expense_repository.dart';
import 'features/expenses/expense_controller.dart';
import 'features/settings/data/hive_settings_repository.dart';
import 'features/settings/settings_controller.dart';
import 'features/categories/category_controller.dart';
import 'features/categories/data/category_repository.dart';
import 'features/categories/data/hive_category_repository.dart';
import 'features/locations/location_controller.dart';
import 'features/locations/data/location_repository.dart';
import 'features/locations/data/hive_location_repository.dart';
import 'features/review/review_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use bundled fonts only (no network downloads) for offline support
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize ads
  await AdService.initialize();

  // Init repositories
  await Hive.initFlutter();

  // --- ENCRYPTION (remove this block + encryptionCipher args below to disable)
  // See lib/core/storage/hive_encryption.dart for full removal instructions.
  final hiveCipher = await HiveEncryption.getCipher();
  // --- END ENCRYPTION

  final expensesBox = await Hive.openBox('expenses', encryptionCipher: hiveCipher);
  final settingsBox = await Hive.openBox('settings', encryptionCipher: hiveCipher);
  final categoriesBox = await Hive.openBox('categories', encryptionCipher: hiveCipher);
  final locationsBox = await Hive.openBox('locations', encryptionCipher: hiveCipher);

  // Load static currency data and exchange rates
  final currencyRegistry = await CurrencyRegistry.load();
  final exchangeRates = await CurrencyRateProvider.loadRates(settingsBox);
  final currencyService = CurrencyService(exchangeRates, currencyRegistry, settingsBox);

  // Load hive repositories
  final expenseRepository = HiveExpenseRepository(expensesBox);
  final settingsRepository = HiveSettingsRepository(settingsBox);
  final categoriesRepository = HiveCategoryRepository(categoriesBox);
  final locationsRepository = HiveLocationRepository(locationsBox);

  // Create ad service and preload interstitial
  final adService = AdService();
  adService.loadInterstitial();

  final reviewService = ReviewService(settingsRepository);

  // Create controllers with cross-references for cascade sync
  final converter = PrimaryCurrencyConverter(
    expenseRepository: expenseRepository,
    currencyService: currencyService,
    settingsRepository: settingsRepository,
  );

  final settingsController = SettingsController(
    settingsRepository,
    currencyConverter: converter,
  );

  final categoryController = CategoryController(
    categoriesRepository,
    expenseRepository,
  );

  final expenseController = ExpenseController(
    expenseRepository,
    categoriesRepository,
    locationsRepository,
    currencyService,
    settingsController,
  );

  final locationController = LocationController(
    locationsRepository,
    expenseRepository,
    onExpensesModified: () => expenseController.reload(),
  );

  // Wire converter callback now that expenseController exists
  converter.onExpensesModified = () => expenseController.reload();

  // Invalidate cached week/month totals when firstDayOfWeek changes
  settingsController.addListener(expenseController.invalidateTotals);

  // Invalidate cached totals when category/location metadata (name, color) changes
  categoryController.addListener(expenseController.invalidateTotals);
  locationController.addListener(expenseController.invalidateTotals);

  runApp(
    MultiProvider(
      providers: [
        Provider<CurrencyRegistry>.value(value: currencyRegistry),
        ChangeNotifierProvider<CurrencyService>.value(value: currencyService),
        ChangeNotifierProvider.value(value: adService),
        ChangeNotifierProvider.value(value: settingsController),
        Provider<ExpenseRepository>.value(value: expenseRepository),
        Provider<CategoryRepository>.value(value: categoriesRepository),
        Provider<LocationRepository>.value(value: locationsRepository),
        ChangeNotifierProvider.value(value: expenseController),
        ChangeNotifierProvider.value(value: categoryController),
        ChangeNotifierProvider.value(value: locationController),
        Provider<ReviewService>.value(value: reviewService),
      ],
      child: SpendingTrackerApp(expenseRepository: expenseRepository),
    ),
  );
}
