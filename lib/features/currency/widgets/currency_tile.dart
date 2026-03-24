import 'package:flutter/material.dart';

import '../models/currency.dart';

/// A list tile displaying currency information.
///
/// Shows currency code, name, and symbol in a consistent format.
class CurrencyTile extends StatelessWidget {
  final Currency currency;
  final bool isSelected;
  final bool dense;
  final VoidCallback? onTap;

  const CurrencyTile({
    super.key,
    required this.currency,
    this.isSelected = false,
    this.dense = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeSize = dense ? 36.0 : 40.0;
    final fontSize = dense ? 14.0 : 16.0;
    final badgePadding = dense ? 6.0 : 8.0;

    return ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : null,
      leading: Container(
        width: badgeSize,
        height: badgeSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(dense ? 6 : 8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(badgePadding),
            child: Text(
              currency.symbol,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
      title: Text(
        dense ? '${currency.code} — ${currency.name}' : currency.code,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: dense
          ? null
          : Text(
              currency.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary, size: dense ? 20 : 24)
          : null,
      onTap: onTap,
    );
  }
}
