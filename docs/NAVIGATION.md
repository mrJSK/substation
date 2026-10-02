# SubERP — Navigation Architecture

**Entry point:** See `CLAUDE.md`.

---

## Mobile / Android

### Bottom Navigation (5 tabs — daily use only)

| Index | Tab | Route | Who |
|-------|-----|-------|-----|
| 0 | Logsheet | `/logsheet` | SSO, Shift Engineer — enters readings every hour |
| 1 | Work Orders | `/wo` | Maintenance JE — checks WOs during shift |
| 2 | PTW | `/ptw` | Shift Engineer — active permits |
| 3 | Defects | `/defects` | Any shift staff — log as discovered |
| 4 | More | opens Drawer | — |

**Rule:** Only put tabs here if a field operator opens it during a normal 8-hour shift.

### Tabs inside modules (TabBar, top of screen)

| Module | Tab 1 | Tab 2 | Tab 3 |
|--------|-------|-------|-------|
| Logsheet | Current Shift | History | Handover |
| PTW | Active | Pending Approval | Closed Today |
| Work Orders | My WOs | All Open | Completed |
| Energy | Today's Readings | Monthly Balance | ABT Blocks |

### Drawer Menu (hamburger — everything else)

```
── Daily Operations ──
  Shift Arrangement    (Reg 4)
  SLDC Message Log     (Reg 16a/b)
  Stoppage Register    (Reg 11)
  Tripping Register    (Reg 10)
  Rostering            (Reg 15)

── Energy & Billing ──
  Energy Account       (Reg 8)
  Max/Min Load         (Reg 17)
  LA Surge Counter     (Reg 18)

── Maintenance ──
  Maintenance Schedule
  Equipment Master     (Reg 2)
  Testing Register     (Reg 6)

── [ADMIN — hidden if no IAM permission] ──
  User Management
  Roles & Permissions
  Authorization Register (Reg 12)

── Reports ──
  Availability %
  SAIDI / SAIFI
  Dashboard

── ──
  Settings
  My Profile / Certificates
  Logout
```

All drawer items are role-gated: hidden if user lacks the required permission.

---

## Desktop / Windows

Left sidebar instead of bottom nav. Two panels:
- **Sidebar** (240px wide): grouped menu items (same as drawer above)
- **Content area**: main panel, fills remaining width

No bottom navigation on desktop.

---

## Web

Same as Desktop. The sidebar collapses on narrow browser windows (< 768px) into a hamburger.

---

## GoRouter Implementation

```dart
// StatefulShellRoute preserves scroll + back stack per tab
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) =>
      AppShell(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/logsheet', ...)]),
    StatefulShellBranch(routes: [GoRoute(path: '/wo', ...)]),
    StatefulShellBranch(routes: [GoRoute(path: '/ptw', ...)]),
    StatefulShellBranch(routes: [GoRoute(path: '/defects', ...)]),
  ],
)
```

The `AppShell` widget:
- Mobile: renders `Scaffold` with `BottomNavigationBar`
- Desktop/Web: renders `Scaffold` with `NavigationDrawer` / left sidebar
- Platform detection: `kIsWeb` + `defaultTargetPlatform`

---

## Route Guard (auth redirect)

```dart
GoRouter(
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isLoginRoute = state.uri.path == '/login';
    if (!isLoggedIn && !isLoginRoute) return '/login';
    if (isLoggedIn && isLoginRoute) return '/launchpad';
    return null;
  },
)
```

---

## Deep Links (Android + Web)

Every module has a deep-linkable route:
- `suberp://ptw/PTW-2026-0042` → opens that specific PTW
- `suberp://wo/WO-2026-0123` → opens that work order
- Useful for FCM push notifications: tap notification → opens the right screen
