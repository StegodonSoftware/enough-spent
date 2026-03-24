# Design Decisions

Future UX and visual design decisions with rationale. These document planned features that haven't been implemented yet.

---

## Sub-Categories

### Structure
- **One level only:** Main categories can have sub-categories, but no deeper nesting
- **Color inheritance:** Sub-categories inherit their parent's color (not user-selectable)
- **Main category color:** User-selected, enforced as the visual identifier

### Visual Treatment: Thick Horizontal Borders

Sub-categories are distinguished from main categories using thick top and bottom borders in the parent's color, with a lighter/transparent fill.

```
Main category:     [████████████]  (solid fill)
Sub-category:      [════════════]  (thick top/bottom border, light fill)
```

#### Why This Approach

| Option | Rejected Because |
|--------|------------------|
| Color shade variation | User-selected colors could cause sub shades to overlap with other main categories |
| Text prefix ("Food / Coffee") | Takes too much horizontal space in compact UI |
| Small parent badge | Adds visual complexity, harder to parse quickly |
| Size difference | Inconsistent visual weight, doesn't scale well |

#### Implementation Notes
- Border should be thick enough (2-3px) to make the color clearly visible
- Fill can be white/transparent or very light tint of parent color
- Works equally well in chips, dropdowns, and list items

---

## Category Limit (Max 10)

### Design
- **Fixed limit of 10 categories** including both active and inactive
- Users can deactivate categories they no longer need, freeing up visual space but not the slot
- Deactivated categories remain linked to their historical expenses
- Users can reactivate or edit existing categories at any time

### Rationale
A hard limit keeps the UI manageable and encourages meaningful categorization rather than over-granular tagging. The limit includes inactive categories to prevent gaming the system by deactivating old ones to create new ones endlessly.

### Future Consideration
- Option to **permanently delete** a category (removes it from all expenses, frees the slot)
- This is intentionally deferred since it's a destructive action requiring careful UX (confirmation, impact preview)

---

## Category Selector (Quick Entry Screen)

### Design: Horizontal Scroll + Search Field

Replaces the wrapping chip grid with a more compact, scalable solution.

#### Components

1. **Horizontal scroll row**
   - Fixed-width chips (~80-100px)
   - Text truncates with ellipsis if too long
   - Sorted by usage frequency (most used first)
   - Single row, no vertical wrapping

2. **Selection behavior**
   - Tapping a chip selects it
   - Selected chip animates wider to reveal full category name
   - Selection indicated by border/highlight styling
   - Tapping again deselects (animates back to truncated width)

3. **Search field below**
   - Autocomplete text field (like location picker)
   - Dropdown shows color dot + full category name
   - Can search all categories, not just frequently used
   - Selecting from dropdown also updates the scroll row selection

#### Why This Approach

| Concern | Solution |
|---------|----------|
| Too much vertical space from wrapping chips | Horizontal scroll = fixed single row |
| Too much padding on chips | Compact fixed-width chips with tighter padding |
| Doesn't scale to many categories | Search field handles discovery |
| Doesn't scale to sub-categories | Search naturally groups/filters hierarchy |
| Quick access to common categories | Frequency-sorted scroll row |

#### Animation Details
- Expansion: 150-200ms ease-out
- Smooth width transition, siblings slide right naturally
- No vertical layout shift (contained in scroll area)
