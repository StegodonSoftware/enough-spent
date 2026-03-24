import 'package:flutter/material.dart';

import '../models/location.dart';

/// Represents the current selection state for the location field.
/// Either an existing location (by ID) or a new location name to be created.
class LocationSelection {
  final String? existingLocationId;
  final String? newLocationName;

  const LocationSelection.existing(String id)
      : existingLocationId = id,
        newLocationName = null;

  const LocationSelection.newLocation(String name)
      : existingLocationId = null,
        newLocationName = name;

  const LocationSelection.none()
      : existingLocationId = null,
        newLocationName = null;

  bool get isEmpty => existingLocationId == null && newLocationName == null;
  bool get isExisting => existingLocationId != null;
  bool get isNew => newLocationName != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationSelection &&
          runtimeType == other.runtimeType &&
          existingLocationId == other.existingLocationId &&
          newLocationName == other.newLocationName;

  @override
  int get hashCode => Object.hash(existingLocationId, newLocationName);
}

/// A location input field with autocomplete and quick-select chips.
///
/// Features:
/// - Horizontal scroll row of top used location chips (up to 10)
/// - Autocomplete text field that filters existing locations
/// - Option to add a new location when no match found
/// - Shows "NEW" badge when a new location name is entered
class LocationAutocompleteField extends StatefulWidget {
  /// All available locations.
  final List<Location> locations;

  /// Top most used locations (shown as chips).
  final List<Location> topUsed;

  /// Current selection.
  final LocationSelection selection;

  /// Called when selection changes.
  final ValueChanged<LocationSelection> onChanged;

  /// Optional focus node for external focus management.
  final FocusNode? focusNode;

  const LocationAutocompleteField({
    super.key,
    required this.locations,
    required this.topUsed,
    required this.selection,
    required this.onChanged,
    this.focusNode,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;

  /// Maximum chips shown before "More..." appears.
  static const int _maxChips = 10;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _scrollController = ScrollController();

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _focusNode.addListener(_onFocusChanged);
    _syncTextFromSelection();
  }

  @override
  void didUpdateWidget(LocationAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update focus node if changed
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _focusNode.addListener(_onFocusChanged);
    }

    // Only sync text if selection changed AND we don't have focus
    // (to avoid interfering with user typing)
    if (widget.selection != oldWidget.selection && !_hasFocus) {
      _syncTextFromSelection();
    }
  }

  void _onFocusChanged() {
    final hadFocus = _hasFocus;
    _hasFocus = _focusNode.hasFocus;

    if (_hasFocus) {
      // Scroll the field into view at the top of the scrollable area
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    } else if (hadFocus) {
      // When losing focus, finalize the selection based on current text
      _finalizeSelection();
    }
  }

  void _finalizeSelection() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      if (!widget.selection.isEmpty) {
        widget.onChanged(const LocationSelection.none());
      }
      return;
    }

    // Check if it matches an existing location (case-insensitive)
    final match = widget.locations
        .where((l) => l.name.toLowerCase() == text.toLowerCase())
        .firstOrNull;

    if (match != null) {
      if (widget.selection.existingLocationId != match.id) {
        widget.onChanged(LocationSelection.existing(match.id));
      }
    } else {
      if (widget.selection.newLocationName != text) {
        widget.onChanged(LocationSelection.newLocation(text));
      }
    }
  }

  void _syncTextFromSelection() {
    if (widget.selection.isExisting) {
      final location = widget.locations
          .where((l) => l.id == widget.selection.existingLocationId)
          .firstOrNull;
      _textController.text = location?.name ?? '';
    } else if (widget.selection.isNew) {
      _textController.text = widget.selection.newLocationName ?? '';
    } else {
      _textController.text = '';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _scrollController.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _selectLocation(Location location) {
    _textController.text = location.name;
    widget.onChanged(LocationSelection.existing(location.id));
  }

  void _selectNewLocation(String name) {
    _textController.text = name;
    widget.onChanged(LocationSelection.newLocation(name));
  }

  void _clearSelection() {
    _textController.clear();
    widget.onChanged(const LocationSelection.none());
  }

  /// Determines the current selection state based on text field content.
  /// Used for displaying the NEW badge without triggering parent rebuilds.
  LocationSelection _getCurrentDisplaySelection() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return const LocationSelection.none();
    }

    final match = widget.locations
        .where((l) => l.name.toLowerCase() == text.toLowerCase())
        .firstOrNull;

    if (match != null) {
      return LocationSelection.existing(match.id);
    }
    return LocationSelection.newLocation(text);
  }

  @override
  Widget build(BuildContext context) {
    final showMoreChip = widget.topUsed.length >= _maxChips;
    final chipCount =
        widget.topUsed.length + (showMoreChip ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal scroll row of top used location chips
        if (widget.topUsed.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: chipCount,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                // "More..." chip at the end
                if (index == widget.topUsed.length) {
                  return _SearchMoreChip(
                    onTap: () => _focusNode.requestFocus(),
                  );
                }

                final location = widget.topUsed[index];
                final isSelected =
                    widget.selection.existingLocationId == location.id;
                return _LocationChip(
                  location: location,
                  isSelected: isSelected,
                  onTap: () {
                    if (isSelected) {
                      _clearSelection();
                    } else {
                      _selectLocation(location);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Autocomplete text field
        _buildAutocomplete(),
      ],
    );
  }

  Widget _buildAutocomplete() {
    return Autocomplete<_AutocompleteOption>(
      textEditingController: _textController,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) {
          return const Iterable.empty();
        }

        final matches = widget.locations
            .where((l) => l.name.toLowerCase().contains(query.toLowerCase()))
            .map((l) => _AutocompleteOption.existing(l))
            .toList();

        // Check if exact match exists (case-insensitive)
        final exactMatch = widget.locations
            .any((l) => l.name.toLowerCase() == query.toLowerCase());

        // Add "create new" option if no exact match
        if (!exactMatch && query.isNotEmpty) {
          matches.add(_AutocompleteOption.createNew(query));
        }

        return matches;
      },
      displayStringForOption: (option) => option.displayName,
      onSelected: (option) {
        if (option.isNew) {
          _selectNewLocation(option.newName!);
        } else {
          _selectLocation(option.location!);
        }
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _OptionsDropdown(
          options: options.toList(),
          onSelected: onSelected,
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return _LocationTextField(
          controller: controller,
          focusNode: focusNode,
          getDisplaySelection: _getCurrentDisplaySelection,
          onClear: _clearSelection,
          onSubmitted: (_) {
            onSubmitted();
            _finalizeSelection();
          },
        );
      },
    );
  }
}

/// Option for autocomplete dropdown.
class _AutocompleteOption {
  final Location? location;
  final String? newName;

  _AutocompleteOption.existing(this.location) : newName = null;
  _AutocompleteOption.createNew(this.newName) : location = null;

  bool get isNew => newName != null;
  String get displayName => location?.name ?? newName ?? '';
}

/// Fixed-width chip for quick-selecting a top used location.
class _LocationChip extends StatelessWidget {
  final Location location;
  final bool isSelected;
  final VoidCallback onTap;

  /// Width for unselected chips.
  static const double _collapsedWidth = 96.0;

  /// Maximum width for selected chips.
  static const double _maxExpandedWidth = 160.0;

  /// Animation duration.
  static const Duration _animationDuration = Duration(milliseconds: 180);

  const _LocationChip({
    required this.location,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _animationDuration,
        curve: Curves.easeOut,
        constraints: BoxConstraints(
          minWidth: _collapsedWidth,
          maxWidth: isSelected ? _maxExpandedWidth : _collapsedWidth,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InitialsBadge(initials: location.initials, isSelected: isSelected),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                location.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "More..." chip shown when there are more locations than the chip limit.
class _SearchMoreChip extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchMoreChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'More\u2026',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary : colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSelected ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Text field with optional "NEW" badge suffix.
/// Uses a callback to get the current display selection to show the NEW badge
/// based on live text content without triggering parent rebuilds.
class _LocationTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final LocationSelection Function() getDisplaySelection;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  const _LocationTextField({
    required this.controller,
    required this.focusNode,
    required this.getDisplaySelection,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  State<_LocationTextField> createState() => _LocationTextFieldState();
}

class _LocationTextFieldState extends State<_LocationTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_LocationTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // Trigger rebuild to update the NEW badge
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasValue = widget.controller.text.trim().isNotEmpty;
    final displaySelection = widget.getDisplaySelection();

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      decoration: InputDecoration(
        hintText: 'Search or add location',
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "NEW" badge when adding a new location
            if (displaySelection.isNew)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NEW',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            // Clear button
            if (hasValue)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: widget.onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      onSubmitted: widget.onSubmitted,
    );
  }
}

/// Dropdown showing autocomplete options.
class _OptionsDropdown extends StatelessWidget {
  final List<_AutocompleteOption> options;
  final ValueChanged<_AutocompleteOption> onSelected;

  const _OptionsDropdown({
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];

              if (option.isNew) {
                // "Add new" option
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Add "'),
                        TextSpan(
                          text: option.newName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: '" as new location'),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  onTap: () => onSelected(option),
                );
              }

              // Existing location option
              final location = option.location!;
              return ListTile(
                dense: true,
                leading: _InitialsBadge(initials: location.initials),
                title: Text(
                  location.name,
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }
}
