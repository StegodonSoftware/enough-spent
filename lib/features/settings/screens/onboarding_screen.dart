import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../currency/models/currency.dart';
import '../../currency/widgets/currency_list.dart';
import '../settings_controller.dart';

/// First-run onboarding screen for setting up primary currency.
///
/// Guides users through initial setup without warning dialogs.
/// Must complete before accessing the main app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late String _selectedCurrencyCode;

  @override
  void initState() {
    super.initState();
    _selectedCurrencyCode = context.read<SettingsController>().primaryCurrency;
  }

  void _handleCurrencySelect(Currency currency) {
    setState(() {
      _selectedCurrencyCode = currency.code;
    });
  }

  void _handleComplete() {
    final settings = context.read<SettingsController>();
    settings.setPrimaryCurrency(_selectedCurrencyCode);
    settings.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildWelcomeHeader(theme, colorScheme),
            _buildStepContext(theme, colorScheme),
            Expanded(
              child: CurrencyList(
                selectedCode: _selectedCurrencyCode,
                onSelect: _handleCurrencySelect,
                padding: const EdgeInsets.symmetric(vertical: 8),
                trackRecent: false,
              ),
            ),
            _buildFooter(theme, colorScheme),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildWelcomeHeader(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          Text(
            'Welcome to',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enough Spent.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your daily expenses with ease.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContext(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set your primary currency',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This will be the default for new expenses. All totals and insights will display in this currency.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You can change this anytime in Settings.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _handleComplete,
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}
