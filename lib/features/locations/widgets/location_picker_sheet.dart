import 'package:flutter/material.dart';

import '../models/location.dart';

/// Result from the location picker sheet.
/// Can be an existing location, a new location name to create, or cleared (null).
sealed class LocationPickerResult {
  const LocationPickerResult();
}

class LocationSelected extends LocationPickerResult {
  final Location location;
  const LocationSelected(this.location);
}

class LocationCreateNew extends LocationPickerResult {
  final String name;
  const LocationCreateNew(this.name);
}

class LocationCleared extends LocationPickerResult {
  const LocationCleared();
}

/// A bottom sheet for selecting or creating a location.
///
/// Use [showLocationPickerSheet] to display this sheet.
class LocationPickerSheet extends StatefulWidget {
  final String? selectedLocationId;
  final List<Location> locations;
  final ValueChanged<LocationPickerResult> onSelect;

  const LocationPickerSheet({
    super.key,
    this.selectedLocationId,
    required this.locations,
    required this.onSelect,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Location> get _filteredLocations {
    if (_searchQuery.isEmpty) return widget.locations;
    return widget.locations
        .where((l) => l.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  bool get _showAddNew {
    if (_searchQuery.isEmpty) return false;
    // Show "add new" if no exact match exists
    return !widget.locations
        .any((l) => l.name.toLowerCase() == _searchQuery.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(context),
          _buildHeader(context),
          _buildSearchField(context),
          const Divider(height: 1),
          Expanded(
            child: _buildList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Select Location',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search or add location',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        textCapitalization: TextCapitalization.words,
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredLocations;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filtered.length + (_showAddNew ? 2 : 1), // +1 for "None", +1 for "Add new" if shown
      itemBuilder: (context, index) {
        // First item: "None" option
        if (index == 0) {
          final isSelected = widget.selectedLocationId == null ||
              widget.selectedLocationId!.isEmpty;
          return ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              'None',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check, color: colorScheme.primary)
                : null,
            onTap: () => widget.onSelect(const LocationCleared()),
          );
        }

        // Second item (if showing): "Add new" option
        if (_showAddNew && index == 1) {
          return ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Add "'),
                  TextSpan(
                    text: _searchQuery,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: '"'),
                ],
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            onTap: () => widget.onSelect(LocationCreateNew(_searchQuery)),
          );
        }

        // Location items
        final locationIndex = index - (_showAddNew ? 2 : 1);
        final location = filtered[locationIndex];
        final isSelected = widget.selectedLocationId == location.id;

        return ListTile(
          leading: _InitialsBadge(
            initials: location.initials,
            isSelected: isSelected,
          ),
          title: Text(
            location.name,
            style: theme.textTheme.bodyLarge,
          ),
          trailing: isSelected
              ? Icon(Icons.check, color: colorScheme.primary)
              : null,
          onTap: () => widget.onSelect(LocationSelected(location)),
        );
      },
    );
  }
}

/// Circular badge showing location initials.
class _InitialsBadge extends StatelessWidget {
  final String initials;
  final bool isSelected;

  const _InitialsBadge({
    required this.initials,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary : colorScheme.outline,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.labelMedium?.copyWith(
          color: isSelected ? colorScheme.onPrimary : colorScheme.surface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shows a modal bottom sheet for location selection.
///
/// Returns a [LocationPickerResult] indicating the user's choice:
/// - [LocationSelected] with the chosen location
/// - [LocationCreateNew] with the name to create
/// - [LocationCleared] to remove the location
/// - null if dismissed without selection
Future<LocationPickerResult?> showLocationPickerSheet(
  BuildContext context, {
  String? selectedLocationId,
  required List<Location> locations,
}) {
  return showModalBottomSheet<LocationPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => LocationPickerSheet(
      selectedLocationId: selectedLocationId,
      locations: locations,
      onSelect: (result) {
        Navigator.pop(context, result);
      },
    ),
  );
}
