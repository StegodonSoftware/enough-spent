import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/expense_category.dart';

class CategoryRow extends StatelessWidget {
  final ExpenseCategory category;
  final int usageCount;
  final VoidCallback? onTap;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;

  const CategoryRow({
    super.key,
    required this.category,
    required this.usageCount,
    this.onTap,
    this.onDeactivate,
    this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final displayColor =
        category.isActive ? category.color : appColors.inactiveCategoryFill;

    return ListTile(
      leading: Container(
        width: 8,
        height: 48,
        decoration: BoxDecoration(
          color: displayColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(
        category.isActive ? category.name : '${category.name} (Inactive)',
        style: TextStyle(
          color: category.isActive ? null : appColors.inactiveCategoryFill,
        ),
      ),
      subtitle: Text(
        usageCount == 0
            ? 'Not used'
            : '$usageCount expense${usageCount == 1 ? '' : 's'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit), onPressed: onTap),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              if (category.isActive)
                PopupMenuItem(
                  value: usageCount == 0 ? 'delete' : 'deactivate',
                  child: Row(
                    children: [
                      Icon(
                        usageCount == 0 ? Icons.delete_outline : Icons.delete,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        usageCount == 0 ? 'Delete' : 'Deactivate',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'reactivate',
                  child: Row(
                    children: [
                      Icon(
                        Icons.restore,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      const Text('Reactivate'),
                    ],
                  ),
                ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'delete':
                case 'deactivate':
                  onDeactivate?.call();
                case 'reactivate':
                  onReactivate?.call();
              }
            },
          ),
        ],
      ),
    );
  }
}
