import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spending_tracker_app/features/expenses/screens/insights_screen.dart';
import 'package:spending_tracker_app/features/expenses/screens/transactions_screen.dart';

import '../features/ads/ad_service.dart';
import '../features/expenses/data/expense_repository.dart';
import '../features/expenses/expense_controller.dart';
import '../features/expenses/screens/quick_entry_screen.dart';
import '../features/settings/screens/settings_screen.dart';

/// Provides navigation capabilities to descendant widgets.
///
/// Use [HomeNavigation.of(context)] to access navigation methods.
class HomeNavigation extends InheritedWidget {
  final void Function(int index) navigateToTab;

  const HomeNavigation({
    super.key,
    required this.navigateToTab,
    required super.child,
  });

  /// Navigate to the Add Expense tab (index 0).
  static void goToAddExpense(BuildContext context) {
    of(context)?.navigateToTab(0);
  }

  static HomeNavigation? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeNavigation>();
  }

  @override
  bool updateShouldNotify(HomeNavigation oldWidget) => false;
}

class HomeShell extends StatefulWidget {
  final ExpenseRepository expenses;

  const HomeShell({super.key, required this.expenses});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const int _quickEntryIndex = 0;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ExpenseController>().invalidateTotals();
    }
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index <= 3 && index != _currentIndex) {
      // Show interstitial when navigating away from Quick Entry
      if (_currentIndex == _quickEntryIndex) {
        _maybeShowInterstitial();
      }
      setState(() => _currentIndex = index);
    }
  }

  Future<void> _maybeShowInterstitial() async {
    final adService = context.read<AdService>();
    await adService.maybeShowInterstitialOnNavigation();
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return QuickEntryScreen();
      case 1:
        return TransactionsScreen();
      case 2:
        return InsightsScreen();
      case 3:
        return SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return HomeNavigation(
      navigateToTab: _navigateToTab,
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildScreen(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _navigateToTab,
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'New',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.trending_up_outlined),
              selectedIcon: Icon(Icons.trending_up),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
