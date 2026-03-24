import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/currency/currency_service.dart';
import '../../../debug/seed_expenses.dart';
import '../../ads/ad_service.dart';
import '../../categories/category_controller.dart';
import '../../categories/screens/manage_categories_screen.dart';
import '../../expenses/expense_controller.dart';
import '../../locations/location_controller.dart';
import '../../locations/screens/location_management_screen.dart';
import '../settings_controller.dart';
import '../../currency/screens/currency_picker_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _appVersion = '1.0.2';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: 'General'),
          _SettingsCard(
            children: [
              _CurrencyTile(),
              const Divider(height: 1),
              _ExchangeRatesTile(),
              const Divider(height: 1),
              _FirstDayOfWeekTile(),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.category_outlined,
                title: 'Manage Categories',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.location_on_outlined,
                title: 'Manage Locations',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LocationManagementScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'About'),
          _SettingsCard(children: [_AboutContent()]),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: 'Developer'),
            _DeveloperTools(),
          ],
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Version $_appVersion',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return _SettingsTile(
      icon: Icons.attach_money,
      title: 'Primary Currency',
      subtitle: settings.primaryCurrency,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CurrencyPickerScreen()),
        );
      },
    );
  }
}

class _ExchangeRatesTile extends StatefulWidget {
  @override
  State<_ExchangeRatesTile> createState() => _ExchangeRatesTileState();
}

class _ExchangeRatesTileState extends State<_ExchangeRatesTile> {
  bool _isRefreshing = false;
  bool _refreshFailed = false;

  String _formatAge(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);
    if (age.inMinutes < 60) return 'Updated just now';
    if (age.inHours < 24) return 'Updated today';
    if (age.inDays < 2) return 'Updated yesterday';
    return 'Updated ${DateFormat.MMMd().format(timestamp)}';
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final success = await context.read<CurrencyService>().refreshRates();
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        if (!success) _refreshFailed = true;
      });
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't update rates. Try again later."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyService = context.watch<CurrencyService>();

    Widget? trailing;
    if (_isRefreshing) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (currencyService.hasStaleRates && !_refreshFailed) {
      trailing = IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _refresh,
        tooltip: 'Get latest rates',
      );
    }

    return ListTile(
      leading: Icon(Icons.sync, color: theme.colorScheme.onSurfaceVariant),
      title: const Text('Exchange Rates'),
      subtitle: Text(_formatAge(currencyService.ratesTimestamp)),
      trailing: trailing,
    );
  }
}

class _FirstDayOfWeekTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final dayName = settings.firstDayOfWeek == DateTime.sunday
        ? 'Sunday'
        : 'Monday';

    return _SettingsTile(
      icon: Icons.calendar_today_outlined,
      title: 'Week Starts On',
      subtitle: dayName,
      onTap: () => _showDayPicker(context, settings),
    );
  }

  void _showDayPicker(BuildContext context, SettingsController settings) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Week Starts On',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              RadioGroup<int>(
                groupValue: settings.firstDayOfWeek,
                onChanged: (value) {
                  if (value != null) {
                    settings.setFirstDayOfWeek(value);
                    Navigator.pop(sheetContext);
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<int>(
                      title: Text('Monday'),
                      value: DateTime.monday,
                    ),
                    RadioListTile<int>(
                      title: Text('Sunday'),
                      value: DateTime.sunday,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _AboutContent extends StatelessWidget {
  static const _contactEmail = 'enoughspent@stegodonsoftware.com';
  static const _emailSubject = 'Enough Spent. - App Feedback';
  static const _privacyPolicyUrl =
      'https://www.stegodonsoftware.com/enough-spent/privacy-policy.html';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/icon/app_logo.png',
                  width: 28,
                  height: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enough Spent.', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Quickly input and track your daily expenses',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'A simple, privacy-focused expense tracker. All your data stays on your device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _launchEmail(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact & Feedback',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _contactEmail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _launchPrivacyPolicy(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy Policy',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(_privacyPolicyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open privacy policy'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      query: 'subject=${Uri.encodeComponent(_emailSubject)}',
    );

    if (!await launchUrl(emailUri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open email app'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _DeveloperTools extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        _DisableAdsTile(),
        const Divider(height: 1),
        _ExchangeRatesDebugTile(),
        const Divider(height: 1),
        _DeveloperTile(
          icon: Icons.add_chart,
          title: 'Add Sample Data',
          subtitle: 'Adds ~25 expenses with locations',
          onTap: () => _addSampleData(context),
        ),
        const Divider(height: 1),
        _DeveloperTile(
          icon: Icons.delete_forever,
          title: 'Clear All Expenses',
          subtitle: 'Permanently delete all expense data',
          isDestructive: true,
          onTap: () => _confirmClearAll(context),
        ),
      ],
    );
  }

  void _addSampleData(BuildContext context) {
    final expenseController = context.read<ExpenseController>();
    final categoryController = context.read<CategoryController>();
    final locationController = context.read<LocationController>();

    addSampleExpenses(
      expenseController: expenseController,
      categoryController: categoryController,
      locationController: locationController,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added sample expenses'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Expenses?'),
        content: const Text(
          'This will permanently delete all expense data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _clearAllData(context);
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _clearAllData(BuildContext context) {
    final expenseController = context.read<ExpenseController>();
    expenseController.clearAll();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All expenses deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _DisableAdsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final adService = context.watch<AdService>();
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return SwitchListTile(
      secondary: Icon(
        Icons.hide_image_outlined,
        color: colorScheme.onSurfaceVariant,
      ),
      title: const Text('Disable Ads'),
      subtitle: const Text('Hide all ads for screenshots'),
      value: adService.devAdsDisabled,
      onChanged: (value) => adService.setDevAdsDisabled(value),
      inactiveThumbColor: colorScheme.onSurfaceVariant,
      inactiveTrackColor: colorScheme.outlineVariant,
    );
  }
}

class _DeveloperTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DeveloperTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: isDestructive ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
    );
  }
}

/// Debug tile showing exchange rate source and status.
class _ExchangeRatesDebugTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currencyService = context.watch<CurrencyService>();
    final debugInfo = currencyService.getDebugInfo();

    final source = debugInfo['source'] as String;
    final ageInHours = debugInfo['ageInHours'] as int;
    final isStale = debugInfo['isStale'] as bool;

    // Format subtitle with source and age
    final ageText = ageInHours == 0 ? 'just now' : '${ageInHours}h ago';
    final staleIndicator = isStale ? ' • STALE' : '';
    final subtitle = '$source • $ageText$staleIndicator';

    return _DeveloperTile(
      icon: Icons.currency_exchange,
      title: 'Exchange Rates',
      subtitle: subtitle,
      onTap: () => _showRatesDetailsDialog(context, debugInfo),
    );
  }

  void _showRatesDetailsDialog(
    BuildContext context,
    Map<String, dynamic> debugInfo,
  ) {
    final timestamp = debugInfo['timestamp'] as DateTime;
    final formattedTimestamp = DateFormat.yMMMd().add_jm().format(timestamp);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exchange Rates Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Source', value: debugInfo['source'] as String),
            const SizedBox(height: 8),
            _DetailRow(label: 'Timestamp', value: formattedTimestamp),
            const SizedBox(height: 8),
            _DetailRow(label: 'Age', value: '${debugInfo['ageInHours']} hours'),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Status',
              value: (debugInfo['isStale'] as bool) ? 'Stale' : 'Fresh',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Base Currency',
              value: debugInfo['base'] as String,
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Currency Count',
              value: '${debugInfo['currencyCount']}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Simple row for displaying label-value pairs in debug dialogs.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
