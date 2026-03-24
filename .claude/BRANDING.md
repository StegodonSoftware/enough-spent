# Branding Guidelines: Enough Spent.

**App Name:** Enough Spent.

## Brand Overview
- Core Promise: TBD
- Personality: Calm, confident, energetic. Approachable without being cute; bold without overwhelming. Users feel relieved and happy after quick actions.
- Key Differentiator: <5-second entry flow. (Need more)
- Tone of Voice (for copy/toasts): Direct, encouraging, minimal.
- Target Audience: TBD

## Core Palette: Energized Calm

Built for light mode first (airy and readable), with bold teal for energy and muted pastels for categories. Ensures accessibility (WCAG AA contrast) and scales to charts.

### Core Colors
- Background: #F2F7F7
- Surface/Card: #FFFFFF
- Text Primary: #1F2937
- Text Secondary: #4B5563
- Primary/Action: #2E8B96 (buttons, key interactions)
- Primary Variant: #25707A (hover/disabled states)
- Success: #6EC6B8 (save toasts, positive feedback — teal-mint, ties to primary)
- Error: #CB8F7A (warnings, deletes — muted rust, warm but attention-grabbing)
- Info/Neutral: #A8B4D4 (offline notes, subtle messages — soft lavender-blue)
- Divider/Secondary: #E5E7EB (lines, subtle elements)

### Default Category Colors (muted pastels for tags/charts)
- #A7C4E0
- #B8A7E0
- #E0A7C4
- #E0B8A7
- #A7E0C4
- #C4E0A7
- #E0D9A7
- #A7E0E0
- #FAD4A0
- #A7A7E0

#### Special Category States
- **Uncategorized** (no category assigned): Dashed border with #9CA3AF, no fill. Communicates "empty/missing" state.
- **Inactive** (category exists but disabled): Grey fill (#9CA3AF) replacing original category color. Communicates "disabled/archived" state. Label includes "(Inactive)" suffix in selectors.

### Usage Rules
Primary teal for all calls-to-action—ensures quick tappability on the add screen.

## Typography

### Font Family: Manrope (Google Fonts, variable axis for weights)
- Why: Modern geometric sans with open apertures for superior mobile legibility and subtle personality—distinct from bland system defaults while staying trustworthy for finance tracking.
- Fallback: system-ui or sans-serif (instant load if network hiccups).
- Implementation: Subset to Latin characters; preload critical weights (400, 500, 700) for speed.
- Note: Secondary choice is Oufit Google Font. To be evaluated in app.

### Weights:
- Regular (400): Body text, lists.
- Medium (500): Inputs, active states.
- Semi-bold (600): Subheadings, category labels.
- Bold (700): Totals, key headings, emphasis.

### Sizes (responsive, supporting platform Dynamic Type):
- Large Titles/Totals: 28–34pt
- Section Headings: 20–24pt
- Body/Inputs/History Items: 16–18pt (core sweet spot—tap-friendly, scannable)
- Secondary Labels/Toasts: 14–15pt
- Small Notes/Hints: 12–13pt

### Line Height:
- Body/Lists: 1.5 (balances readability with density—fits more history items visible without endless scroll)
Inputs/Quick-Add Fields: 1.6 (extra breathing room for focus and error reduction)
- Headings: 1.3–1.4 (tighter for visual punch)
- Rationale: 1.5 isn't overly airy—it's standard for mobile sans-serif (prevents eye strain on numbers/dates) while keeping screens efficient. Tighter risks cramping; looser wastes real estate.

### Additional Spacing:
- Letter-spacing: Default or +0.02em on headings for openness.
Paragraph margins: 8–16pt between sections—hierarchy without excess scroll.
- Alignment: Left for lists/trends; centered for quick-add prompts.

## Visual Style & UI Guidelines

### Location Badge Pattern
Location badges use a circular shape with initials:
- **Shape**: Circle (BoxShape.circle)
- **Size**: 32x32 for headers/list tiles, 28x28 for inline badges, 18x18 for detail rows
- **Known location**: Primary color background (`colorScheme.primary`), white text (`colorScheme.onPrimary`)
- **Unknown location**: Grey background (`colorScheme.outlineVariant`), grey text (`colorScheme.onSurfaceVariant`), "?" symbol
- **Text style**: fontWeight 600, fontSize scaled to badge size (size * 0.4)
- Used in: ExpenseTile location badge, location tab headers, location picker sheet

To be completed...

## Logo & App Icon

To be completed...