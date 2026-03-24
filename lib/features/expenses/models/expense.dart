class Expense {
  // Maximum length for expense notes to prevent database bloat
  // and ensure reasonable UI display constraints
  static const int maxNoteLength = 500;

  // Upper bound on minor units (~$10M for 2-decimal currencies, ~¥1B for 0-decimal)
  static const int maxAmountMinor = 999999999;

  final String id;
  final int amountMinor; // e.g. cents
  final String? categoryId; // null = uncategorized
  final String? locationId; // null = no location
  final DateTime date;
  final String currencyCode; // ISO code
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Amount converted to primary currency at time of entry (in minor units).
  /// Used as canonical value for totals when primary currency hasn't changed.
  /// Null for legacy expenses (will be migrated on first load).
  final int? amountInPrimary;

  /// Primary currency when this expense was created.
  /// Stored to enable historical accuracy when calculating totals.
  final String? primaryCurrencyCode;

  /// Exchange rate used: 1 [currencyCode] = [rateToPrimary] [primaryCurrencyCode].
  /// Stored for transparency and debugging.
  final double? rateToPrimary;

  /// Date when the conversion rate was applied.
  /// Used for tracking when the expense was converted to primary currency.
  final DateTime? conversionDate;

  Expense({
    required this.id,
    required this.amountMinor,
    this.categoryId,
    this.locationId,
    required this.date,
    required this.currencyCode,
    this.note,
    this.amountInPrimary,
    this.primaryCurrencyCode,
    this.rateToPrimary,
    this.conversionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Expense copyWith({
    int? amountMinor,
    String? currencyCode,
    String? categoryId,
    bool clearCategoryId = false,
    String? locationId,
    bool clearLocationId = false,
    DateTime? date,
    String? note,
    bool clearNote = false,
    int? amountInPrimary,
    String? primaryCurrencyCode,
    double? rateToPrimary,
    DateTime? conversionDate,
  }) {
    return Expense(
      id: id, // immutable
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      locationId: clearLocationId ? null : (locationId ?? this.locationId),
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
      amountInPrimary: amountInPrimary ?? this.amountInPrimary,
      primaryCurrencyCode: primaryCurrencyCode ?? this.primaryCurrencyCode,
      rateToPrimary: rateToPrimary ?? this.rateToPrimary,
      conversionDate: conversionDate ?? this.conversionDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Validates the expense and returns a list of error messages.
  /// Returns an empty list if the expense is valid.
  List<String> validate() {
    final errors = <String>[];

    if (amountMinor <= 0) {
      errors.add('Amount must be greater than zero');
    }

    if (amountMinor > maxAmountMinor) {
      errors.add('Amount exceeds maximum allowed value');
    }

    if (currencyCode.isEmpty || currencyCode.length != 3) {
      errors.add('Invalid currency code (must be 3-letter ISO code)');
    }

    if (note != null && note!.length > maxNoteLength) {
      errors.add('Note is too long (maximum $maxNoteLength characters)');
    }

    return errors;
  }

  /// Returns true if the expense passes all validation rules.
  bool get isValid => validate().isEmpty;

  /// Returns true if this expense has primary currency conversion data.
  /// Legacy expenses without this data need migration.
  bool get hasPrimaryConversion => amountInPrimary != null && primaryCurrencyCode != null;

  factory Expense.fromMap(Map map) {
    // Required fields (match constructor)
    final id = map['id'];
    final amountMinor = map['amountMinor'];
    final date = map['date'];
    final currencyCode = map['currencyCode'];

    if (id == null) {
      throw ArgumentError('Expense.fromMap: missing required field "id"');
    }
    if (amountMinor == null) {
      throw ArgumentError('Expense.fromMap: missing required field "amountMinor"');
    }
    if (date == null) {
      throw ArgumentError('Expense.fromMap: missing required field "date"');
    }
    if (currencyCode == null) {
      throw ArgumentError('Expense.fromMap: missing required field "currencyCode"');
    }

    // Handle legacy empty string values as null
    final categoryId = map['categoryId'] as String?;
    final locationId = map['locationId'] as String?;

    // Migration: Handle old amountInUsd field, map to amountInPrimary with primaryCurrencyCode='USD'
    final amountInPrimary = (map['amountInPrimary'] ?? map['amountInUsd']) as int?;
    final primaryCurrencyCode = map['primaryCurrencyCode'] as String? ?? 'USD';

    // Optional fields use constructor defaults
    return Expense(
      id: id as String,
      amountMinor: amountMinor as int,
      categoryId: (categoryId?.isEmpty ?? true) ? null : categoryId,
      locationId: (locationId?.isEmpty ?? true) ? null : locationId,
      date: DateTime.parse(date as String),
      currencyCode: currencyCode as String,
      note: map['note'] as String?,
      amountInPrimary: amountInPrimary,
      primaryCurrencyCode: primaryCurrencyCode,
      rateToPrimary: ((map['rateToPrimary'] ?? map['rateToUsd']) as num?)?.toDouble(),
      conversionDate: map['conversionDate'] != null
          ? DateTime.parse(map['conversionDate'] as String)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amountMinor': amountMinor,
      if (categoryId != null) 'categoryId': categoryId,
      if (locationId != null) 'locationId': locationId,
      'date': date.toIso8601String(),
      'currencyCode': currencyCode,
      if (note != null) 'note': note,
      if (amountInPrimary != null) 'amountInPrimary': amountInPrimary,
      if (primaryCurrencyCode != null) 'primaryCurrencyCode': primaryCurrencyCode,
      if (rateToPrimary != null) 'rateToPrimary': rateToPrimary,
      if (conversionDate != null) 'conversionDate': conversionDate!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
