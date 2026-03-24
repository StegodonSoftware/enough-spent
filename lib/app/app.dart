import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/expenses/data/expense_repository.dart';
import '../features/settings/screens/onboarding_screen.dart';
import '../features/settings/settings_controller.dart';
import 'home_shell.dart';

class SpendingTrackerApp extends StatelessWidget {
  final ExpenseRepository expenseRepository;

  const SpendingTrackerApp({super.key, required this.expenseRepository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spending Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _HomeRouter(expenses: expenseRepository),
    );
  }
}

/// Routes between onboarding and home based on onboarded status.
class _HomeRouter extends StatelessWidget {
  final ExpenseRepository expenses;

  const _HomeRouter({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return settings.isOnboarded
        ? HomeShell(expenses: expenses)
        : const OnboardingScreen();
  }
}
