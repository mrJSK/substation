# SubERP — UI/UX Guidelines

**Entry point:** See `CLAUDE.md`. These rules apply to every widget in this project.

---

## Design Philosophy

This is a field ERP used by substation engineers and operators — not a consumer app.
- Operators may wear gloves (44px minimum tap targets)
- Used outdoors or in harsh lighting (high contrast required)
- Speed matters: a reading must be enterable in under 10 seconds
- No decoration for its own sake

---

## Colors

```dart
primary:   #2563EB  (blue — all interactive elements, active states)
white:     #FFFFFF  (surface, cards)
bg:        #F8FAFC  (page background)
border:    #E2E8F0  (dividers, input borders)
textPrimary:   #0F172A
textSecondary: #475569
textMuted:     #94A3B8
success:   #16A34A
warning:   #D97706
error:     #DC2626
```

**Rule:** No other colors. No gradients. No teal, orange, purple accents.
Status indicators use only success/warning/error.

---

## Typography

- Body: 13px, regular weight — for data in tables and lists
- Labels/secondary: 12px — timestamps, subtitles
- Titles: 14-15px, SemiBold — screen headers
- Numbers (readings, kV, MW): monospace font or tabular figures
- No large hero text. No display-size fonts.

---

## Buttons

| Situation | Use |
|-----------|-----|
| Navigation, secondary action, most actions | `TextButton` |
| One primary CTA per screen (e.g., "Submit", "Issue PTW") | `ElevatedButton` (blue) |
| Destructive action confirmation | `TextButton` with error color |
| In an AppBar trailing position | `TextButton` or `IconButton` |

**Never:** multiple `ElevatedButton`s on the same screen.

---

## Lists

Use `ListTile` + `Divider` for lists. Not `Card` inside a `ListView`.

```dart
// Correct
ListView.separated(
  itemBuilder: (_, i) => ListTile(title: ..., subtitle: ...),
  separatorBuilder: (_, __) => const Divider(height: 1),
)

// Wrong
ListView.builder(
  itemBuilder: (_, i) => Card(child: ListTile(...)),
)
```

---

## Forms

- Use `reactive_forms` for all multi-field forms (dynamic form engine)
- `isDense: true` on all `TextFormField`
- Label above field (not floating) for data-entry screens
- Numeric keypad (`keyboardType: TextInputType.number`) for all measurement inputs
- Every form has one submit button at the bottom — `ElevatedButton`

---

## Navigation

See `docs/NAVIGATION.md`. Summary:
- Bottom nav: 5 tabs
- Within modules: `TabBar` + `TabBarView`
- Admin/rare: Drawer

---

## Animations

**None.** Do not use:
- `flutter_animate` (not in pubspec)
- `AnimatedContainer` / `AnimatedOpacity` unless strictly functional (e.g., loading state)
- Hero transitions
- Custom page transitions (uses `FadeUpwardsPageTransitionsBuilder` — minimal)

The one permitted animation: `CircularProgressIndicator` for loading states.

---

## Layout

- Side padding: 16px on mobile, 24px on tablet/desktop
- List item height: ~48-52px (dense, readable)
- Section spacing: 16px between sections, 8px between related fields
- AppBar height: 52px (set in theme)
- No nested scrolling unless unavoidable

---

## Data Display (tables, readings)

Substation logsheets are data-heavy. Use:
- `DataTable` widget for tabular data (readings, register entries)
- Monospace font for numeric values (kV, MW, Hz, °C)
- Right-align numbers
- Color-code out-of-range values: warning (yellow) if alarm threshold, error (red) if trip threshold

---

## Web / Desktop differences

- Left sidebar instead of bottom nav (standard desktop ERP pattern)
- Wider content area: max 1200px centered
- Two-column form layout on wide screens
- Otherwise same color, typography, and button rules
