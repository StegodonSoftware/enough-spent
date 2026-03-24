# Release QA Checklist — Enough Spent. v1.0.0

Target: Android phone (single device, no tablet layouts)

---

## 0. Fresh Install (clear app data first)

- [ ] **0.1** App opens to onboarding screen (not home)
- [ ] **0.2** System back button does NOT dismiss onboarding
- [ ] **0.3** Currency list loads with 100+ entries, scrollable
- [ ] **0.4** Selecting a currency and tapping "Get Started" enters the app
- [ ] **0.5** Bottom nav shows 4 tabs: New, Transactions, Insights, Settings
- [ ] **0.6** Quick Entry screen is the default tab
- [ ] **0.7** Transactions and Insights show appropriate empty states
- [ ] **0.8** Settings shows selected primary currency from onboarding

---

## 1. Quick Entry (New tab)

### Basic entry
- [ ] **1.1** Amount field is focused on screen load
- [ ] **1.2** Typing a number enables the Save button
- [ ] **1.3** Save creates expense, shows success toast, haptic feedback
- [ ] **1.4** Amount field clears and re-focuses after save
- [ ] **1.5** Save button disabled when amount field is empty

### Optional details
- [ ] **1.6** Tapping the collapsed section expands it (shows category, location, date, currency, notes)
- [ ] **1.7** Section stays expanded after saving an expense within the same session
- [ ] **1.8** Category field shows autocomplete with most-used categories
- [ ] **1.9** Location field shows top-used locations
- [ ] **1.10** Can create a new location inline from the location field
- [ ] **1.11** Date picker opens and allows selecting past dates
- [ ] **1.12** Currency picker shows recently used currencies at top
- [ ] **1.13** Notes field shows character counter, stops at 500 chars
- [ ] **1.14** Saving with all optional fields populated creates correct expense

### Currency locking
- [ ] **1.15** Lock icon toggles currency lock on/off
- [ ] **1.16** When locked, tapping the currency shows a dialog with unlock/change options
- [ ] **1.17** When unlocked, currency picker opens freely
- [ ] **1.18** Lock state persists across saves within the same session

---

## 2. Transactions (second tab)

### By Date tab
- [ ] **2.1** Expenses grouped by date, most recent first
- [ ] **2.2** Daily totals shown per group header
- [ ] **2.3** Tapping an expense opens the Edit screen

### By Category tab
- [ ] **2.4** Expenses grouped by category
- [ ] **2.5** Category totals shown with color coding
- [ ] **2.6** Uncategorized expenses appear under "Uncategorized"

### By Location tab
- [ ] **2.7** Expenses grouped by location
- [ ] **2.8** Location initials badges display correctly
- [ ] **2.9** Expenses without a location grouped appropriately

### Filter tab
- [ ] **2.10** Can filter by date range
- [ ] **2.11** Can filter by category (multi-select)
- [ ] **2.12** Can filter by location
- [ ] **2.13** Can filter by amount range (min/max)
- [ ] **2.14** Setting min > max shows red error: "Minimum must be less than maximum"
- [ ] **2.15** Apply button disabled when min > max
- [ ] **2.16** Clearing filters resets to showing all expenses
- [ ] **2.17** Filtered result count is accurate

---

## 3. Edit Transaction

- [ ] **3.1** All fields pre-populated with existing values
- [ ] **3.2** Modifying amount + saving updates the expense
- [ ] **3.3** Changing currency triggers primary currency reconversion
- [ ] **3.4** Note field enforces 500-char max
- [ ] **3.5** Created/edited timestamps shown at bottom
- [ ] **3.6** Save disabled until a change is actually made
- [ ] **3.7** **Unsaved changes — back button**: Change the amount, press back → "Discard changes?" dialog appears
- [ ] **3.8** **No changes — back button**: Open and immediately press back → navigates back immediately (no dialog)
- [ ] **3.9** Discard dialog → "Discard" goes back; "Cancel" stays on edit screen
- [ ] **3.10** Can assign/change/clear category on existing expense
- [ ] **3.11** Can assign/change/clear location on existing expense
- [ ] **3.12** If category is inactive, it still displays correctly

---

## 4. Insights (third tab)

### Empty state
- [ ] **4.1** Shows "No insights yet" message when no expenses exist
- [ ] **4.2** Action button navigates to Quick Entry

### Spending tab
- [ ] **4.3** Shows today/this week/this month/all time totals
- [ ] **4.4** Daily average = total / calendar days since first expense
- [ ] **4.5** Weekly average displayed correctly
- [ ] **4.6** Comparison bars (this week vs last week, this month vs last month) show correct data
- [ ] **4.7** Last 7 days bar chart has 7 bars, today on the right

### Categories tab
- [ ] **4.8** Category breakdown with amounts and percentages
- [ ] **4.9** Color coding matches category colors
- [ ] **4.10** Sorted by amount descending

### Locations tab
- [ ] **4.11** Location breakdown with amounts
- [ ] **4.12** Location initials badges display correctly

---

## 5. Settings (fourth tab)

### Primary currency
- [ ] **5.1** Shows current primary currency code
- [ ] **5.2** Tapping opens Currency Picker screen
- [ ] **5.3** Selecting a different currency shows warning dialog about conversion
- [ ] **5.4** Confirming converts ALL expenses (including ones already in the primary currency)
- [ ] **5.5** Totals update immediately after conversion
- [ ] **5.6** New primary appears in recent currencies list

### Week starts on
- [ ] **5.7** Can toggle between Monday and Sunday
- [ ] **5.8** Change affects weekly calculations in Insights

### About section
- [ ] **5.9** App name, tagline, privacy message displayed
- [ ] **5.10** Contact & Feedback button opens email client

---

## 6. Category Management (Settings → Manage Categories)

- [ ] **6.1** Shows active categories with count (X/10)
- [ ] **6.2** Shows inactive categories section (if any exist)
- [ ] **6.3** Search field filters the list

### Add category
- [ ] **6.4** FAB opens add sheet
- [ ] **6.5** Name field has 30-char limit with counter
- [ ] **6.6** Add button disabled when name is empty
- [ ] **6.7** Duplicate name (case-insensitive) rejected
- [ ] **6.8** Color picker allows selection from palette
- [ ] **6.9** Cannot add past 10 total categories (button disabled, shows "X of 10 used")

### Edit category
- [ ] **6.10** Tap category row opens edit sheet
- [ ] **6.11** Name field pre-populated, has 30-char limit
- [ ] **6.12** Save disabled when name is cleared to empty
- [ ] **6.13** Duplicate name on edit rejected

### Delete category
- [ ] **6.14** Unused category: deleted completely, undo available via snackbar
- [ ] **6.15** Used category: deactivated (not deleted), toast says "deactivated"
- [ ] **6.16** Deactivated category appears in inactive section

### Reactivate category
- [ ] **6.17** Tap inactive category → reactivates it
- [ ] **6.18** Reactivated category appears in active section

---

## 7. Location Management (Settings → Manage Locations)

- [ ] **7.1** Shows all locations with usage counts
- [ ] **7.2** Sort options: Most Used, A-Z, Recently Added all work
- [ ] **7.3** Search field filters the list
- [ ] **7.4** Location initials badges display correctly

### Edit location
- [ ] **7.5** Tap location row opens edit sheet
- [ ] **7.6** Name field has 100-char limit
- [ ] **7.7** Entering an existing location name shows inline error: "A location with this name already exists"
- [ ] **7.8** Save disabled when name is duplicate or empty

### Delete location
- [ ] **7.9** Delete removes the location
- [ ] **7.10** If location has expenses: warning shows affected count, location cleared from those expenses
- [ ] **7.11** Transaction list immediately reflects the change (no stale data)
- [ ] **7.12** Undo via snackbar restores location AND re-links all affected expenses

### Merge locations
- [ ] **7.13** Merge option available when 2+ locations exist
- [ ] **7.14** Target selection sheet shows searchable location list
- [ ] **7.15** Confirmation shows affected expense count and warns source will be deleted
- [ ] **7.16** After merge: source deleted, expenses updated to target
- [ ] **7.17** Undo restores source location and reverts all expense references

---

## 8. Currency Display & Formatting

- [ ] **8.1** USD expense: shows 2 decimal places (e.g. $ 10.50)
- [ ] **8.2** JPY expense: shows 0 decimal places (e.g. ¥ 1530)
- [ ] **8.3** EUR expense: shows 2 decimal places with € symbol
- [ ] **8.4** Amount displays correctly in all screens (Quick Entry, Transactions, Insights, Edit)
- [ ] **8.5** Comma input accepted as decimal separator (e.g. "10,50" → $10.50)

---

## 9. Currency Conversion Integrity

- [ ] **9.1** New expense auto-converts to primary currency on save
- [ ] **9.2** Change primary (USD → EUR): ALL expenses convert, including USD ones
- [ ] **9.3** Change primary (EUR → JPY): amounts correct for cross-rate (no intermediate rounding errors)
- [ ] **9.4** Conversion stores rate used (visible in debug tools)
- [ ] **9.5** Original amount + original currency preserved after conversion

---

## 10. Recent Currencies

- [ ] **10.1** Using different currencies adds them to recent list
- [ ] **10.2** Recent list limited to 5 entries
- [ ] **10.3** Most recently used currency appears first
- [ ] **10.4** Primary currency always in the recent list
- [ ] **10.5** Recents persist after closing and reopening the app

---

## 11. Averages & Totals Accuracy

- [ ] **11.1** Daily average: total / calendar days since first expense (not days-with-expenses)
- [ ] **11.2** Weekly average: total / calendar weeks since first expense
- [ ] **11.3** Monthly average: total / distinct months with expenses
- [ ] **11.4** This month daily average: total this month / days-with-expenses this month
- [ ] **11.5** Background resume: leave app, return → totals refresh (especially after midnight)

---

## 12. Validation & Limits

- [ ] **12.1** Amount over 999,999,999 minor units (~$10M) rejected
- [ ] **12.2** Negative amounts rejected
- [ ] **12.3** Non-numeric input rejected in amount field
- [ ] **12.4** Note length capped at 500 characters
- [ ] **12.5** Category name capped at 30 characters
- [ ] **12.6** Location name capped at 100 characters
- [ ] **12.7** Max 10 categories enforced (add button disabled at limit)

---

## 13. Ads

- [ ] **13.1** Banner ad loads at bottom of Quick Entry screen
- [ ] **13.2** Banner ad loads at bottom of Transactions screen
- [ ] **13.3** Banner ad loads at bottom of Insights screen
- [ ] **13.4** Ads do not obscure content or input fields
- [ ] **13.5** App remains usable when ad fails to load (no crash, no blank space issues)

---

## 14. Debug Tools (debug builds only)

- [ ] **14.1** Developer Tools section visible in Settings
- [ ] **14.2** Exchange Rates tile shows source, age, stale status
- [ ] **14.3** Add Sample Data creates ~25 expenses with UUID IDs
- [ ] **14.4** Clear All Expenses requires confirmation, then removes everything

---

## Smoke Test Order

Fastest path through the most critical functionality. Run this first — if anything fails here, stop and fix before continuing.

1. **Fresh install** → onboarding completes (0.1–0.4)
2. **Quick entry** → create a USD expense (1.1–1.3)
3. **Quick entry with details** → create JPY expense with category + location (1.6, 1.8–1.9, 8.2)
4. **Transactions** → verify both expenses appear by date (2.1–2.3)
5. **Edit expense** → modify amount, save, verify back-button dialog (3.1–3.2, 3.7–3.8)
6. **Insights** → verify totals and daily average (4.3–4.4)
7. **Change primary currency** → USD to EUR, verify conversion (5.2–5.5, 9.2)
8. **Category management** → add, edit empty name blocked, hit 10 limit (6.4–6.9, 6.12)
9. **Location management** → edit duplicate name, delete with cascade + undo (7.7, 7.10–7.12)
10. **Filter** → set min > max, verify error (2.14–2.15)
