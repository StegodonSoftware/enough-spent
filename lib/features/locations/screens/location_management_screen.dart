import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/toast/toast.dart';
import '../location_controller.dart';
import '../models/location.dart';

/// Sort options for the location list.
enum LocationSortOption {
  mostUsed('Most Used'),
  alphabetical('A-Z'),
  recentlyAdded('Recently Added');

  final String label;
  const LocationSortOption(this.label);
}

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final _searchController = TextEditingController();
  LocationSortOption _sortOption = LocationSortOption.mostUsed;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Location> _getSortedLocations(
    LocationController controller,
    String query,
  ) {
    final List<Location> base;
    switch (_sortOption) {
      case LocationSortOption.mostUsed:
        base = controller.allSortedByUsage;
      case LocationSortOption.alphabetical:
        base = controller.allSortedAlphabetically;
      case LocationSortOption.recentlyAdded:
        base = controller.allSortedByRecentlyAdded;
    }

    if (query.isEmpty) return base;
    final normalized = query.toLowerCase();
    return base
        .where((l) => l.name.toLowerCase().contains(normalized))
        .toList();
  }

  void _showEditSheet(BuildContext context, Location location) {
    final controller = context.read<LocationController>();
    final nameController = TextEditingController(text: location.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final theme = Theme.of(sheetContext);

        return StatefulBuilder(
          builder: (context, setModalState) {
            final name = nameController.text.trim();
            final isNameTaken = name.isNotEmpty &&
                !controller.isNameAvailable(name, excludeId: location.id);
            final isValid = name.isNotEmpty &&
                name.length <= Location.maxNameLength &&
                !isNameTaken;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Location',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      errorText: isNameTaken
                          ? 'A location with this name already exists'
                          : null,
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    maxLength: Location.maxNameLength,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isValid
                          ? () {
                              controller.updateLocation(
                                location.id,
                                name: name,
                              );
                              Navigator.pop(context);
                              Toast.show(context, message: 'Location updated');
                            }
                          : null,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, Location location) {
    final controller = context.read<LocationController>();
    final usageCount = controller.usageCount(location.id);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: const Text('Delete Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Delete '${location.name}'?"),
              if (usageCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will clear the location from $usageCount expense${usageCount == 1 ? '' : 's'}.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () {
                final result = controller.deleteLocationWithCascade(location.id);
                Navigator.pop(dialogContext);
                if (result != null) {
                  Toast.show(
                    context,
                    message: 'Location deleted',
                    actionLabel: 'Undo',
                    onAction: () => controller.undoDelete(result),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showMergeSheet(BuildContext context, Location sourceLocation) {
    final controller = context.read<LocationController>();
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim();
            final normalized = query.toLowerCase();
            final filteredLocations = controller.allSortedByUsage
                .where((l) => l.id != sourceLocation.id)
                .where((l) => query.isEmpty || l.name.toLowerCase().contains(normalized))
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Merge "${sourceLocation.name}" into...',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select the location to keep',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: 'Search locations...',
                                prefixIcon: const Icon(Icons.search),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                suffixIcon: query.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          searchController.clear();
                                          setModalState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: filteredLocations.isEmpty
                            ? Center(
                                child: Text(
                                  query.isEmpty
                                      ? 'No other locations'
                                      : 'No matching locations',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: filteredLocations.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final target = filteredLocations[index];
                                  final usageCount =
                                      controller.usageCount(target.id);

                                  return ListTile(
                                    leading: _InitialsBadge(
                                      initials: target.initials,
                                    ),
                                    title: Text(target.name),
                                    subtitle: Text(
                                      '$usageCount expense${usageCount == 1 ? '' : 's'}',
                                    ),
                                    onTap: () => _confirmMerge(
                                      context,
                                      sourceLocation,
                                      target,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmMerge(
    BuildContext context,
    Location source,
    Location target,
  ) {
    final controller = context.read<LocationController>();
    final sourceUsage = controller.usageCount(source.id);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: const Text('Confirm Merge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    const TextSpan(text: 'Merge '),
                    TextSpan(
                      text: '"${source.name}"',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ' into '),
                    TextSpan(
                      text: '"${target.name}"',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '?'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$sourceUsage expense${sourceUsage == 1 ? '' : 's'} will be updated to "${target.name}".',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"${source.name}" will be deleted.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final result = controller.mergeLocations(source.id, target.id);
                Navigator.pop(dialogContext);
                Navigator.pop(context); // Close merge sheet
                if (result != null) {
                  Toast.show(
                    this.context,
                    message:
                        'Merged into "${target.name}" (${result.affectedCount} updated)',
                    actionLabel: 'Undo',
                    onAction: () => controller.undoMerge(result),
                  );
                }
              },
              child: const Text('Merge'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<LocationController>();
    final query = _searchController.text.trim();
    final locations = _getSortedLocations(controller, query);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Locations')),
      body: Column(
        children: [
          // Search and sort controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search locations...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Sort dropdown
                Row(
                  children: [
                    Text(
                      'Sort by:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IntrinsicWidth(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minHeight: 36),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<LocationSortOption>(
                            value: _sortOption,
                            isDense: true,
                            items: LocationSortOption.values.map((option) {
                              return DropdownMenuItem(
                                value: option,
                                child: Text(option.label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _sortOption = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${locations.length} location${locations.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Location list
          Expanded(
            child: locations.isEmpty
                ? _EmptyState(
                    hasQuery: query.isNotEmpty,
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : ListView.separated(
                    itemCount: locations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final location = locations[index];
                      final usageCount = controller.usageCount(location.id);

                      return _LocationRow(
                        location: location,
                        usageCount: usageCount,
                        onEdit: () => _showEditSheet(context, location),
                        onDelete: () =>
                            _showDeleteConfirmation(context, location),
                        onMerge: controller.all.length > 1
                            ? () => _showMergeSheet(context, location)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Row widget for displaying a location in the list.
class _LocationRow extends StatelessWidget {
  final Location location;
  final int usageCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMerge;

  const _LocationRow({
    required this.location,
    required this.usageCount,
    required this.onEdit,
    required this.onDelete,
    this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onEdit,
      leading: _InitialsBadge(initials: location.initials),
      title: Text(location.name),
      subtitle: Text(
        usageCount == 0
            ? 'Not used'
            : '$usageCount expense${usageCount == 1 ? '' : 's'}',
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (context) => [
          if (onMerge != null)
            PopupMenuItem(
              value: 'merge',
              child: Row(
                children: [
                  Icon(
                    Icons.merge,
                    size: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  const Text('Merge'),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  'Delete',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          switch (value) {
            case 'merge':
              onMerge?.call();
            case 'delete':
              onDelete();
          }
        },
      ),
    );
  }
}

/// Circular badge showing location initials.
class _InitialsBadge extends StatelessWidget {
  final String initials;

  const _InitialsBadge({required this.initials});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Empty state shown when no locations exist or match search.
class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  final VoidCallback onClearSearch;

  const _EmptyState({
    required this.hasQuery,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.location_on_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No matching locations' : 'No locations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Locations are created when you add them to expenses.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (hasQuery) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onClearSearch,
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
