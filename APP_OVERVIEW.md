# Enough Spent. — App Overview for Marketing

**App Name:** Enough Spent.
**Platform:** Android (iOS-compatible codebase)
**Version:** 1.0.3 (Build 4)
**Tagline (from onboarding):** "Track your daily expenses with ease."
**Theme:** Energized calm — teal (#2E8B96) primary color, light muted background, clean Material Design 3 UI

---

## 1. Complete Feature List

### Expense Entry
- Quick expense entry screen — the default landing tab every time the app opens
- Amount entry with automatic formatting per currency (e.g. $10.50 vs ¥1050)
- Optional category assignment per expense (color-coded, auto-suggested by usage frequency)
- Optional location assignment per expense (create locations on the fly)
- Optional date override (defaults to today)
- Optional free-text note per expense (up to 500 characters)
- Per-expense currency — any individual transaction can be logged in a different currency than your primary (useful for travel)
- "Locked currency" mode — a setting that pins a single currency for quick entry without being prompted (useful when traveling and every purchase is in one foreign currency)
- Haptic feedback on successful save
- Success toast notification after saving, with the app resetting for the next entry
- Auto-focus on the amount field so you can start typing immediately
- The optional fields (category, location, date, note) are hidden by default beneath a visual divider to keep the screen uncluttered — they expand and stay open once used

### Transaction History
- **By Date tab:** All expenses grouped by calendar date, newest first, with collapsible date headers and a running total per day
- **By Category tab:** All expenses grouped by category, with a running total per category; uncategorized expenses appear in their own section
- **By Location tab:** All expenses grouped by location, with a running total per location; expenses with no location assigned appear in an "Unknown" section
- **Filter tab:** Advanced filtering with:
  - Date presets: Today, This Week, This Month, Last 30 Days
  - Custom date range picker (any start and end date)
  - Amount range filter (minimum, maximum, or both)
  - Multi-select category filter
  - Multi-select location filter
  - Active filter count badge displayed on the tab
  - One-tap reset to clear all filters
- Inline delete on any transaction with a 3-second undo option via toast
- Tap any transaction to open a full edit screen for all fields

### Expense Editing
- Edit every field of a saved expense: amount, currency, category, location, date, note
- Conversion data is updated automatically when currency or amount changes

### Spending Insights
Three tabs of analytics, all calculated from your local data:

**Spending tab:**
- Today's total
- This week's total vs last week's total (with visual comparison)
- This month's total vs last month's total (with visual comparison)
- All-time totals with daily and monthly averages
- 7-day bar chart (last 7 days of spending)
- This week's and last week's daily average
- Week start day is user-configurable (Sunday or Monday)

**Categories tab:**
- Total spent per category (all time)
- Proportion bar showing each category's share of total spending
- Top categories this week and this month (ranked)
- Uncategorized expenses shown separately

**Locations tab:**
- Total spent per location (all time)
- Proportion bar showing each location's share
- Top locations this week and this month (ranked)

### Category Management
- Up to 10 categories (active and inactive combined)
- 7 default categories pre-loaded: Accommodation, Bills, Food, Transport, Health, Entertainment, Shopping
- Create custom categories with a name (up to 30 characters) and a color from a curated 10-color palette or a custom color picker
- Edit name and color at any time
- Deactivate a category (soft delete) — it disappears from new entry but remains linked to historical data; can be reactivated anytime
- Search/filter within the category list
- Inactive categories shown in a separate section with a "Reactivate" option

### Location Management
- Unlimited locations
- Create with a name (up to 100 characters); auto-generated display initials
- Optional GPS coordinates stored per location (both latitude and longitude, or neither)
- Edit name, initials, and coordinates
- Delete a location with a 3-second undo option
- Search by name
- Sort by: Most Used (default), Alphabetical (A–Z), Recently Added
- Usage count shown per location (how many expenses reference it)

### Currency System
- 162 ISO 4217 fiat currencies supported
- Set a primary currency on first launch (and change it any time in Settings)
- Changing the primary currency triggers a batch re-conversion of all historical expenses, with a warning dialog explaining the impact
- Each expense stores its original currency, original amount, exchange rate used, and the converted primary-currency amount — so the conversion is transparent and auditable
- Exchange rates fetched from a remote API; bundled fallback rates included so the app works fully offline
- "Popular" currencies (USD, EUR, GBP, JPY, AUD, CAD) sorted to the top of the currency picker
- Tracks your 5 most recently used currencies for quick access
- Per-expense currency override (log one expense in EUR even if your primary is USD)

### Settings
- Primary currency (with batch conversion support)
- Week start day: Sunday or Monday
- Link to Manage Categories screen
- Link to Manage Locations screen
- About section (placeholder for legal/links)
- App version displayed at the bottom

### Onboarding
- Single-screen first-launch experience: pick your primary currency
- "You can change this anytime in Settings" — low-pressure messaging
- Cannot be dismissed without selecting a currency (back button is disabled)
- Full 162-currency list with popular currencies at the top

### Monetization
- **Banner ad** displayed at the bottom of the Transactions screen
- **Interstitial ad** shown after leaving the Quick Entry screen once you've logged 10 expenses since the last interstitial
- Uses Google AdMob; test ad IDs in debug builds, production IDs in release builds
- Ads fail silently when offline — app works exactly the same without internet

---

## 2. User Flow

### First Launch
1. App opens to the **Onboarding screen** — "Welcome to Enough Spent."
2. User sees a full list of 162 currencies with USD, EUR, GBP, JPY, AUD, CAD at the top
3. User taps their currency, taps **"Get Started"**
4. App opens to the **Quick Entry screen** (Tab 1 of 4)

### Logging an Expense (Fastest Path — 3 taps)
1. App opens directly to Quick Entry — the amount field is already focused
2. Type amount (e.g. "850")
3. Tap **Save** (large button)
4. Done. Haptic feedback fires, a success toast appears, and the amount field clears for the next entry

### Logging an Expense with Details (Power User Path)
1. Enter amount
2. Tap the category field → pick from list or type to filter
3. Tap the location field → pick existing or type a new one to create it
4. Optionally change the date (tapping opens a date picker)
5. Optionally type a note
6. Tap Save

### Viewing Past Expenses
1. Tap the **Transactions** tab (Tab 2)
2. Default view is By Date — scroll up to see older expenses
3. Tap **By Category** or **By Location** tabs to switch groupings
4. Tap **Filter** tab to narrow by date, amount, category, or location

### Checking Spending Insights
1. Tap the **Insights** tab (Tab 3)
2. Default view shows today's total, this week vs last week, this month vs last month, and a 7-day bar chart
3. Tap **Categories** tab to see breakdown by category
4. Tap **Locations** tab to see breakdown by location

### Changing Primary Currency
1. Tap **Settings** tab (Tab 4)
2. Tap **Primary Currency**
3. Pick new currency from the list
4. A warning dialog explains that all past expenses will be re-converted — tap Confirm
5. A toast appears confirming the conversion is complete
6. All insight totals are now in the new currency

---

## 3. Permissions & Privacy

### Android Permissions Requested
| Permission | Why |
|---|---|
| `INTERNET` | Fetch live exchange rates; load AdMob ads |
| `ACCESS_NETWORK_STATE` | Check connectivity before attempting network calls |
| `com.google.android.gms.permission.AD_ID` | Required by Google AdMob for ad targeting |

**No location permission is requested.** GPS coordinates can optionally be stored with locations, but the app does not access the device's GPS — coordinates must be entered manually.

### Network Calls
The app makes exactly **two kinds of network calls**:
1. **Currency exchange rates** — fetches a JSON file of exchange rates (base: USD) from a remote API. Used only for converting expenses between currencies. The fetched data is not linked to any user identity.
2. **Google AdMob** — loads and displays banner and interstitial ads.

Both calls fail gracefully: the app ships with bundled fallback exchange rates and works fully offline. Ads simply don't appear when offline.

### Analytics & Crash Reporting
**None.** The app contains no Firebase, Sentry, Crashlytics, Mixpanel, Amplitude, or any other analytics or crash reporting SDK. There is zero telemetry.

### Third-Party SDKs
| SDK | Purpose |
|---|---|
| Google Mobile Ads (AdMob) 5.3.0 | Banner and interstitial ads |
| Hive 2.2.3 | Local database |
| Provider 6.1.2 | State management (internal) |
| intl 0.19.0 | Number/date formatting |
| Google Fonts 6.2.1 | Manrope typeface (bundled offline) |
| uuid 4.5.1 | Generating unique IDs |
| dotted_border 2.1.0 | UI decoration |
| http 1.2.0 | Currency API calls |
| url_launcher 6.3.1 | Opening URLs (About section) |
| flutter_secure_storage 9.2.2 | Storing Hive encryption key |

**All user expense data stays on-device.** Nothing is uploaded to any server. The only identifiable data ever leaving the device is what AdMob collects for ad serving (governed by Google's privacy policy).

---

## 4. Supported Currencies

**162 ISO 4217 fiat currencies** are supported, loaded from a bundled `currencies.json` file.

Each currency stores:
- 3-letter ISO code (USD, EUR, JPY, etc.)
- Full name
- Symbol
- Decimal places (2 for most currencies, 0 for zero-decimal currencies like JPY and KRW)
- Minor unit denominator (how many minor units = 1 major unit)

**Popular currencies sorted to top:** USD, EUR, GBP, JPY, AUD, CAD

Exchange rates are fetched live from a remote API with USD as the base currency. A complete set of fallback rates is bundled in the app so conversions still work offline (though the rates may be slightly out of date).

---

## 5. Data & Storage

### How Data Is Stored
All data is stored **locally on the device** using Hive, a fast NoSQL key-value database. There is no cloud backend, no account required, and no sync. The database is encrypted using a cipher key stored in Android Keystore (and iOS Keychain on iOS).

**What is stored:**
- All expenses (amount, currency, category, location, date, note, and conversion metadata)
- Categories (name, color, active status)
- Locations (name, initials, optional GPS coordinates)
- Settings (primary currency, week start day, onboarding status, recent currencies, locked currency preference)
- Bundled exchange rates (updated from network when available)

### Export
**There is no export feature in the current version.** Export functionality is listed as a planned future feature.

### Backup & Restore
**There is no backup or restore feature in the current version.** Data sync/backup is listed as a planned future feature. If a user uninstalls the app or changes devices, their data is not recoverable (unless Android device backup captures the app data).

---

## 6. Anything Unique or Noteworthy

### Ultra-Fast Entry by Design
The Quick Entry screen is the default landing tab every time — not a home dashboard or summary screen. The amount field is auto-focused on open so you can literally start typing immediately. The design philosophy: logging an expense should take under 5 seconds. Optional fields (category, location, date, note) are hidden below a visual divider so they don't slow down the common case.

### Per-Expense Currency with Automatic Conversion
Most budget apps force you to use one currency. Enough Spent. lets you log any expense in any of 162 currencies and still see unified totals. Each expense stores both its original amount/currency and the converted primary-currency amount, along with the exchange rate and date of conversion. This makes mixed-currency trips seamless.

### Locked Currency Travel Mode
A setting that pins one currency for quick entry — useful when you're abroad for a week and every purchase is in the local currency. You can flip it on, travel, flip it off when you're back home, without having to change your primary currency.

### Soft-Delete Categories with History Preservation
Deleting a category doesn't break historical data. Categories are deactivated (soft-deleted) and can be restored. Expenses that used that category still show the category name on edit; the category just won't appear as an option for new entries. This is intentional — your history stays clean.

### Batch Currency Reconversion with Recovery
When you change your primary currency, the app reconverts every single historical expense to the new currency. A safety flag is set before the batch operation and cleared on success — if the app crashes mid-conversion, the flag is detected on next launch and the conversion automatically retries.

### Glassmorphic Toast System
The app has a custom toast notification system (not the system-level Android toast). Toasts slide up from the bottom with an elastic icon pop-in animation. They support action buttons — the delete toast includes "Undo" that lets you recover a deleted expense within 3 seconds. Toast types: success (teal-mint), error (rust-red), warning, info (lavender), neutral.

### Insights Are Calculated Locally, Instantly
No server round-trips for analytics. All daily/weekly/monthly totals, averages, comparisons, and breakdowns are computed in-app using a dirty-flag optimization: calculations only run when the underlying expense data actually changes, not on every screen redraw.

### No Account, No Login, No Cloud
The app works entirely offline and requires no account. This is a genuine privacy feature: there is no way for the developer to see any user's financial data because it never leaves the device.

### Encryption at Rest
Expense data is stored in an encrypted Hive database. The encryption key is generated on first run and stored in Android Keystore, meaning it's tied to the device and can't easily be extracted.

### Material Design 3 Polish
The app uses current (2025) Material Design 3 components throughout: NavigationBar (not the older BottomNavigationBar), FilledButton (not ElevatedButton), proper ColorScheme-based theming, and pill-shaped tab indicators. The Manrope typeface is bundled in the app for consistent rendering without a network call.

### Location Initials Badges
Locations are displayed with circular initials badges (like contact avatars) throughout the app — in transaction lists, insights, and the location picker. Unknown locations show a "?" badge. This makes locations visually scannable at a glance.

### Configurable Week Start Day
Weekly spending totals respect the user's preferred week start day (Sunday or Monday). This affects the "This Week" calculation in insights, the weekly average, and the week-over-week comparisons.

### Planned Features (Roadmap Signal for Marketing)
The following are explicitly planned but not yet built — useful for roadmap messaging:
- Receipt photo attachments
- Export (CSV/PDF presumably)
- Cloud backup and restore
- Sub-categories (hierarchical)
- Comprehensive test coverage
