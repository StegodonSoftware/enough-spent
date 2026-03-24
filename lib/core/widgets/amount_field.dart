import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/currency/models/currency.dart';
import '../../features/currency/currency_amount.dart';

class AmountField extends StatefulWidget {
  final Currency currency;
  final int? initialMinorUnits;

  /// Called when the amount changes. Passes null when the field is empty or invalid.
  final ValueChanged<int?> onChangedMinor;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Optional upper bound on minor units. When exceeded, the field shows an
  /// error and reports null to [onChangedMinor].
  final int? maxMinorUnits;

  const AmountField({
    super.key,
    required this.currency,
    required this.onChangedMinor,
    this.initialMinorUnits,
    this.focusNode,
    this.autofocus = true,
    this.maxMinorUnits,
  });

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsNode;
  String? _errorText;
  int? _lastMinor; // last valid parsed value

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();

    if (widget.initialMinorUnits != null) {
      _lastMinor = widget.initialMinorUnits;
      final value = widget.initialMinorUnits! / widget.currency.numToBasic;
      _controller.text = value.toStringAsFixed(widget.currency.decimals);
    }

    _ownsNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currency.code != widget.currency.code) {
      _reformatForNewCurrency(oldWidget.currency);
    }
  }

  /// Reformats the current amount for a new currency's decimal places.
  void _reformatForNewCurrency(Currency oldCurrency) {
    if (_lastMinor == null) return;

    // Convert old minor units back to major using the OLD currency's factor
    final majorAmount = _lastMinor! / oldCurrency.numToBasic;
    final formatted = majorAmount.toStringAsFixed(widget.currency.decimals);
    _controller.text = formatted;

    // Re-parse and notify parent with new minor units
    final result = parseCurrencyAmount(formatted, widget.currency);
    if (result.isValid) {
      _lastMinor = result.minorUnits;
      // Defer callback — didUpdateWidget runs during the build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChangedMinor(result.minorUnits!);
      });
    }
  }

  void _handleChanged(String text) {
    final result = parseCurrencyAmount(text, widget.currency);

    if (result.isValid &&
        widget.maxMinorUnits != null &&
        result.minorUnits! > widget.maxMinorUnits!) {
      setState(() => _errorText = 'Amount too large');
      _lastMinor = null;
      widget.onChangedMinor(null);
      return;
    }

    setState(() {
      _errorText = result.error;
    });

    if (result.isValid) {
      _lastMinor = result.minorUnits;
      widget.onChangedMinor(result.minorUnits!);
    } else {
      _lastMinor = null;
      widget.onChangedMinor(null);
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) return;

    // Focus LOST → normalize text
    if (_lastMinor == null) {
      _controller.clear();
      return;
    }

    final normalized = (_lastMinor! / widget.currency.numToBasic)
        .toStringAsFixed(widget.currency.decimals);

    _controller.text = normalized;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: false,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      autofocus: widget.autofocus,
      style: theme.textTheme.headlineMedium,
      decoration: InputDecoration(
        labelText: 'Amount *',
        suffix: Text(
          widget.currency.code,
          style: TextStyle(color: colorScheme.primary),
        ),
        prefixText: '${widget.currency.symbol} ',
        prefixStyle: theme.textTheme.headlineMedium?.copyWith(
          color: colorScheme.primary,
        ),
        errorText: _errorText,
        // Underline style with transparent background
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      onChanged: _handleChanged,
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsNode) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }
}
