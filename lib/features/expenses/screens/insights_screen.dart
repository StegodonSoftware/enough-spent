import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/home_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../ads/widgets/banner_ad_widget.dart';
import '../expense_controller.dart';
import 'insights_categories_tab.dart';
import 'insights_locations_tab.dart';
import 'insights_spending_tab.dart';

/// Main insights screen with tabbed navigation for Spending and Categories views.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenseController = context.watch<ExpenseController>();
    final colorScheme = Theme.of(context).colorScheme;

    final hasExpenses = expenseController.all.isNotEmpty;

    if (!hasExpenses) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: EmptyState(
          icon: Icons.insights_outlined,
          title: 'No insights yet',
          subtitle: 'Start tracking your spending to see insights and trends',
          actionLabel: 'Add Expense',
          onAction: () => HomeNavigation.goToAddExpense(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        bottom: TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.start,
          isScrollable: true,
          dividerHeight: 0,
          // Pill indicator styling
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          indicatorPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),
          // Label styling
          labelColor: colorScheme.onPrimaryContainer,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          // Splash styling
          splashBorderRadius: BorderRadius.circular(20),
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: const [
            Tab(text: 'Spending', height: 36),
            Tab(text: 'Categories', height: 36),
            Tab(text: 'Locations', height: 36),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                InsightsSpendingTab(),
                InsightsCategoriesTab(),
                InsightsLocationsTab(),
              ],
            ),
          ),
          const SafeArea(
            top: false,
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }
}
