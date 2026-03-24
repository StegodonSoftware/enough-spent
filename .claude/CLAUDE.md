# Spending Tracker App

A Flutter-based personal expense tracking application for managing daily expenses with categories, insights, and multi-currency support.

## Project Overview

**Current Stage:** Early-to-mid development (v1.0.1+2)
- Core features implemented and functional
- Production-ready first version
- Need major launch promotion and advertisement
- Looking to drive first adoption
- Initial monetization through add revenue, with premium offers later

**Key Features:**
- Quick expense entry with optional categorization
- Transaction history (by date and by category and location)
- Spending insights (daily, weekly and monthly summaries)
- Category management with custom colors
- Multi-currency support (100+ fiat currencies)
- Local-first with Hive database

## Architecture Principles

### Folder Structure
- **Feature-first organization**: `features/expenses/`, `features/categories/`
- **Clear separation**: `data/`, `models/`, `screens/`, controllers
- **Core utilities**: `core/` for shared cross-cutting concerns
- **Repository pattern**: Abstract interfaces with Hive implementations

### State Management
- **Provider** with ChangeNotifier pattern
- **Controllers** for business logic (ExpenseController, CategoryController)
- **Computed properties** with dirty flag optimization
- **Separation of concerns**:
  - **Screens are dumb**: Complex calculations, filtering, sorting belong in controllers
  - **Controllers compute, screens display**: Business logic and data transformations stay out of build methods
  - Screens should only handle layout, styling, and user interaction
- **Provider usage patterns**:
  - Use `context.watch<T>()` in build methods for reactive values
  - Use `context.select<T, R>()` for targeted rebuilds (performance-critical screens)
  - Always use `context.read<T>()` in callbacks/event handlers
  - Never use `watch` in callbacks (causes unnecessary rebuilds)

### Data Layer
- **Hive** for local key-value storage
- **Repository pattern** decouples persistence from business logic
- **Immutable models** with copyWith patterns
- **Timestamps** on all entities (createdAt, updatedAt)

## Flutter Best Practices

### Modern Flutter Standards (2025+)
- **Always use latest stable Flutter SDK features**
- **Material Design 3** components (not Material 2):
  - `FilledButton`, `FilledButton.tonal` (not `ElevatedButton`)
  - `OutlinedButton` (not `FlatButton` or `TextButton` with borders)
  - Use `colorScheme` properties, not deprecated `primaryColor`
- **Null safety**: Enabled and strictly enforced
- **Sound null safety patterns**:
  - Prefer `late final` for deferred initialization
  - Use `?`, `!`, `??` appropriately
  - Never use `!` without being certain value is non-null
- **Modern Color API**: Use `Color.withValues(alpha:)` not deprecated `withOpacity()`
- **MediaQuery best practices**: Use `MediaQuery.sizeOf(context)` not `MediaQuery.of(context).size`

### Widget & UI
- **Const constructors** wherever possible for performance
- **Dispose** all controllers, focus nodes, and listeners properly
- Keep widgets **focused and single-purpose**
- Prefer **composition** over deep widget trees

### Theming
- **Single source of truth**: All theme config in `core/theme/`
- **AppTheme**: Main `ThemeData` with `ColorScheme` for Material colors
- **AppColors**: `ThemeExtension` for app-specific colors (category palette, etc.)
- **Brand colors**: Defined in `BRANDING.md`, implemented in `app_theme.dart`
- **Usage patterns**:
  - Material colors: `Theme.of(context).colorScheme.primary`
  - App colors: `context.appColors.categoryPalette` (via extension)
  - Text styles: `Theme.of(context).textTheme.titleLarge`
- **Never hardcode colors** in widgets - always use theme
- **Typography**: Manrope font family with weights 400, 500, 600, 700

### Code Style
- Use `final` over `var` for immutability
- Leverage **null safety** properly (?, !, ??)
- **Meaningful variable names** over abbreviations
- Avoid commented out code in all files
- **Extract magic numbers and values** to named constants:
  - Numbers used multiple times or with business meaning
  - String literals that represent configuration
  - Duration values (timeouts, animation durations)
  - Size/dimension values that could change
  - **Location**: Static const at top of class
  - **Naming**: Use descriptive names (e.g., `maxNoteLength`, not `max`)
  - **Documentation**: Always comment the "why" for non-obvious values

### Performance vs. Readability
- **Default**: Prioritize readability (clear code over clever tricks)
- **Exceptions where performance matters**:
  - Quick entry screen (user-facing speed critical)
  - Anywhere performance would be noticeably improved for users
- Use `const` constructors where it improves performance meaningfully
- Profile before optimizing - don't guess

### Documentation & Comments
- **Default**: Code should be self-documenting
  - Use clear variable/method names
  - Keep functions focused and simple
- **Do comment**:
  - Complex logic that isn't instantly readable
  - Constants (especially hex codes, unicode values)
  - Non-obvious business rules
  - The "why" behind decisions, not the "what"
- **Don't comment**:
  - Obvious code
  - Restating what the code does

### Focus Management
- Pass `FocusNode` as optional parameters for reusable widgets
- Always dispose owned focus nodes
- Use `requestFocus()` to guide user flow

## Data Conventions

### Core Rules
- **Currency codes**: 3-letter ISO codes (USD, EUR, JPY, etc.)
- **Category/Location IDs**: `String?` type; `null` = not set
- **Amounts**: Store as **minor units** (cents) in integers
- **Timestamps**: Always include `createdAt` and `updatedAt` on models

### Validation & Error Handling
- **Validate in models**, not just UI
  - Use `validate()` method returning `List<String>` of errors
  - Provide `isValid` getter for quick checks
- **Error handling philosophy**:
  - All errors should be logged
  - Development: Throw errors loudly (fail fast, easier debugging)
  - Production: Show graceful user-friendly messages
  - Use `assert` for development-only checks
  - Never silently swallow errors
- **Throw errors for missing required fields** in deserialization
  - Example: `currencyCode` must not be null in `fromMap()`
  - Don't hide data integrity problems with silent fallbacks

### Optional References (Category, Location)
- Use `null` for `categoryId` when no category selected (uncategorized)
- Use `null` for `locationId` when no location set
- Display uncategorized as "Uncategorized" in UI
- Check with `categoryId == null` (not `.isEmpty`)
- Use `clearCategoryId`/`clearLocationId` in `copyWith()` to explicitly set to null

## Code Quality Standards

### Serialization
- **Required fields**: Always include in `toMap()`, throw `ArgumentError` if missing in `fromMap()`
- **Optional fields**: Use conditional inclusion in `toMap()`: `if (note != null) 'note': note`
- **`fromMap()` must mirror constructor**: Required fields throw if null, optional fields use constructor defaults
- Handle legacy empty strings as `null` for optional reference fields (categoryId, locationId)

### State Updates
- Avoid redundant `setState` calls
- Check if value changed before calling `setState`
- Use dirty flags for expensive computed properties

### Model Design
- **Immutable classes** with final fields
- **copyWith methods** with clear semantics for nullable fields
  - Use `clearNote` pattern for explicitly clearing optional fields
- Include **validation methods** on models
- Provide **factory constructors** for deserialization

## Testing Strategy 

### Test Priority Order
1. **Repository Layer Tests** (Priority A - highest value, often missed)
   - Unit tests for all Hive repository implementations using `hive_test`
   - Validates real serialization round-trips, not just fake in-memory behavior
   - Use `setUpTestHive()` / `tearDownTestHive()` from `hive_test` package
   - Note: `box.clear()` is fully async (awaits disk IO); `deleteAll()` void interfaces cannot be reliably tested for immediate effect — cover via integration tests
2. **Model/Business Logic Tests** (Priority A - highest value)
   - Unit tests for all models (validate, copyWith, serialization)
   - Unit tests for controllers (business logic, state management)
   - Fastest to write, highest ROI
3. **Widget Tests** (Priority B - critical screens)
   - Quick entry screen
   - Insights screen
   - Transaction list screens
4. **Integration Tests** (Priority C - full flows)
   - End-to-end user flows
   - Multi-screen interactions

### Target
- \>70% code coverage
- All business logic tested before UI tests
- Critical user paths covered

## Development Workflow

### Git Conventions
- Descriptive commit messages focused on "why"
- Co-authored commits when using AI assistance
- Never force push to main/master

### Screen Design Philosophy
- **Quick entry screen**: Optimized for speed
  - Critical fields first (amount + save button)
  - Optional details below divider
  - Focus management for rapid entry

## Tech Stack

- **Flutter SDK**: Dart 3.10.4+ (use latest stable features)
- **State**: Provider v6.1.2
- **Database**: Hive v2.2.3
- **Formatting**: intl v0.19.0
- **Typography**: google_fonts v6.2.1 (Manrope)
- **Linting**: flutter_lints v6.0.0

## Code Modernization Policy

- **Stay current**: Always use the latest non-deprecated APIs
- **Deprecation warnings**: Fix immediately, never ignore
- **Migration**: When Flutter/Dart introduces breaking changes:
  - Update to new APIs promptly
  - Use migration tools when available
  - Document why old patterns were replaced
- **Reference latest docs**: Check official Flutter/Dart docs for current best practices

## Future Enhancements (Planned)

- Sub-categories for hierarchical organization
- Receipt attachments
- Export functionality
- Data sync/backup
- Comprehensive test suite
- Surface unconverted expense counts in insights when currency conversion fails
- Option to permanently delete categories (remove from all expenses, free slot)
