import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/currency_registry.dart';
import '../models/currency.dart';
import '../../settings/settings_controller.dart';
import 'currency_tile.dart';

/// A searchable, sectioned list of currencies.
///
/// Displays currencies grouped by: Recently Used, Common, and All.
/// Supports search filtering and selection indication.
class CurrencyList extends StatefulWidget {
  /// Called when a currency is selected.
  final ValueChanged<Currency> onSelect;

  /// The currently selected currency code, if any.
  final String? selectedCode;

  /// Whether to show the search field.
  final bool showSearch;

  /// Whether to use compact row height for bottom sheets.
  final bool dense;

  /// Whether to mark selected currency as recently used.
  final bool trackRecent;

  /// Optional padding around the list content.
  final EdgeInsetsGeometry? padding;

  const CurrencyList({
    super.key,
    required this.onSelect,
    this.selectedCode,
    this.showSearch = true,
    this.dense = false,
    this.trackRecent = true,
    this.padding,
  });

  @override
  State<CurrencyList> createState() => _CurrencyListState();
}

class _CurrencyListState extends State<CurrencyList> {
  String _query = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _matchesSearch(Currency c) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return c.code.toLowerCase().contains(q) ||
        c.name.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<CurrencyRegistry>();
    final settings = context.watch<SettingsController>();

    final all = registry.all;
    final recent = settings.recentCurrencies
        .map(registry.getByCode)
        .whereType<Currency>()
        .toList();
    final common = registry.commonCurrencies;

    // Exclude recent and common from "All" section to avoid duplicates
    final excludedCodes = {
      ...recent.map((c) => c.code),
      ...common.map((c) => c.code),
    };

    final filteredRecent = recent.where(_matchesSearch).toList();
    final filteredCommon = common.where(_matchesSearch).toList();
    final filteredAll = all
        .where(_matchesSearch)
        .where((c) => !excludedCodes.contains(c.code))
        .toList();

    return Column(
      children: [
        if (widget.showSearch) _buildSearchField(),
        Expanded(
          child: ListView(
            padding: widget.padding,
            children: [
              if (widget.trackRecent && filteredRecent.isNotEmpty)
                _buildSection('Recently Used', filteredRecent),
              if (filteredCommon.isNotEmpty)
                _buildSection('Common', filteredCommon),
              _buildSection('All Currencies', filteredAll),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search currency',
          border: const OutlineInputBorder(),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() => _query = value.trim());
        },
      ),
    );
  }

  void _handleSelect(Currency currency) {
    if (widget.trackRecent) {
      context.read<SettingsController>().markCurrencyUsed(currency.code);
    }
    widget.onSelect(currency);
  }

  Widget _buildSection(String title, List<Currency> currencies) {
    if (currencies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title, dense: widget.dense),
        ...currencies.map(
          (c) => CurrencyTile(
            currency: c,
            isSelected: c.code == widget.selectedCode,
            dense: widget.dense,
            onTap: () => _handleSelect(c),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool dense;

  const _SectionHeader(this.title, {this.dense = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, dense ? 12 : 20, 16, dense ? 4 : 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
