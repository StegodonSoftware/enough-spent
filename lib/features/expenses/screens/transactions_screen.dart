import 'package:flutter/material.dart';

import '../../ads/widgets/banner_ad_widget.dart';
import 'transactions_by_date_tab.dart';
import 'transactions_by_category_tab.dart';
import 'transactions_by_location_tab.dart';
import 'transactions_filter_tab.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
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
            Tab(text: 'Date', height: 36),
            Tab(text: 'Category', height: 36),
            Tab(text: 'Location', height: 36),
            Tab(text: 'Filter', height: 36),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                TransactionsByDateTab(),
                TransactionsByCategoryTab(),
                TransactionsByLocationTab(),
                TransactionsFilterTab(),
              ],
            ),
          ),
          const SafeArea(top: false, child: BannerAdWidget()),
        ],
      ),
    );
  }
}
