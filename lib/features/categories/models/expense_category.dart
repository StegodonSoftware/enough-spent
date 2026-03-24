import 'dart:ui';

class ExpenseCategory {
  final String id;
  final String name;
  final int colorValue; // ARGB int
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const int maxNameLength = 30;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get color => Color(colorValue);

  /// Validates the category and returns a list of error messages.
  /// Empty list means the category is valid.
  List<String> validate() {
    final errors = <String>[];

    if (id.trim().isEmpty) {
      errors.add('Category ID cannot be empty');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      errors.add('Category name cannot be empty');
    } else if (trimmedName.length > maxNameLength) {
      errors.add('Category name cannot exceed $maxNameLength characters');
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;

  ExpenseCategory copyWith({
    String? name,
    bool? isActive,
    int? colorValue,
    DateTime? updatedAt,
  }) {
    return ExpenseCategory(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ExpenseCategory.fromMap(Map map) {
    // Required fields (match constructor)
    final id = map['id'];
    final name = map['name'];
    final colorValue = map['colorValue'];

    if (id == null) {
      throw ArgumentError('ExpenseCategory.fromMap: missing required field "id"');
    }
    if (name == null) {
      throw ArgumentError('ExpenseCategory.fromMap: missing required field "name"');
    }
    if (colorValue == null) {
      throw ArgumentError('ExpenseCategory.fromMap: missing required field "colorValue"');
    }

    // Optional fields use constructor defaults
    return ExpenseCategory(
      id: id as String,
      name: name as String,
      colorValue: colorValue as int,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}

const defaultCategoryNames = [
  'Accommodation',
  'Bills',
  'Food',
  'Transport',
  'Health',
  'Entertainment',
  'Shopping',
];
