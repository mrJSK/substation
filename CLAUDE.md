# SubERP — Project Context for Claude

This file is read automatically at every Claude Code session. Read it first, then read `docs/` for depth.

---

## What This Is

**SubERP** is a professional, sellable ERP system for Indian power utilities (DISCOMs, TRANSCOs, GENCOs) — comparable to SAP ERP in scope. NOT a hobby app. Built to be licensed to real utilities.

Target customers: UPTCL, UPPCL, MSEDCL, BESCOM, POWERGRID substations etc.

The system covers substation Operations & Maintenance: shift logging, Permit to Work, equipment maintenance, energy accounting, reliability reporting — all mapped to Indian statutory registers (UPPTCL, CEA, CERC, IEGC).

---

## Products

| Product | Platform | Who uses it |
|---------|----------|-------------|
| Operator App | Flutter mobile (Android) | SSO, Shift Engineers, JEs in the field |
| Desktop App | Flutter Windows | Control room computers |
| Web Portal | Flutter Web | Managers, EEs, CEs — dashboards & admin |

One Flutter codebase, three build targets. No separate React/Next.js.

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Frontend | Flutter 3.47.5 / Dart 3.13.4 | Cross-platform: mobile + desktop + web |
| Backend | Supabase (PostgreSQL + RLS) | Firebase was deleted; Supabase is better for relational ERP data |
| Auth | Supabase Auth (PKCE flow) | SSO/SAML for enterprise DISCOMs |
| Realtime | Supabase Realtime | PTW alerts, active permit status only |
| Storage | Supabase Storage | Documents, drawings, test reports |
| State | Riverpod 2.x (flutter_riverpod) | Production-grade reactive state |
| Navigation | go_router 14.x | Shell routes for bottom nav launchpad |
| Local cache | Hive CE | Offline equipment/org-unit cache (no re-fetch every shift) |
| Offline queue | Drift (SQLite) | Queue logsheet writes when offline, batch sync |
| Models | Freezed 3.x | Immutable, copyWith, json_serializable |
| Forms | reactive_forms | Dynamic form engine for admin-configurable forms |
| PDF | pdf + printing | Generate statutory register PDFs |
| Charts | fl_chart | SAIDI/SAIFI trends, transformer load |

**Firebase is completely removed.** Never add firebase_* packages.

---

## Architecture Decisions

### Multi-tenancy
Every Firestore document has `tenant_id`. Supabase RLS policies enforce isolation:
```sql
create policy tenant_isolation on equipment using (tenant_id = current_tenant_id());
```

### Org Hierarchy (7 levels)
```
Tenant (utility company)
  Zone → Circle → Division → Subdivision → Substation → Bay
```
Stored in `org_units` table with `path ltree` for fast ancestor queries.

### Permission Model (SAP-style 3-axis RBAC)
```
Permission = (What: permission code) × (Where: org_unit scope) × (Who: role)
```
Tables: `roles` → `permissions` → `role_permissions` → `user_role_assignments` (scoped to org_unit)

### Offline-First Mobile (CRITICAL — old Firebase app was shut down due to API cost)
- Equipment list, org units: cached in Hive with 48hr TTL — never re-fetched each shift
- Logsheet entries: queued locally in Drift, batch-synced every 15 min or on shift close
- Supabase Realtime: only active PTWs and critical alerts
- Never `select *` — always name columns
- No polling; use Realtime push

### Code Generation
Run after editing any `@riverpod`, `@freezed`, or `@DriftDatabase` annotated file:
```
dart run build_runner build --delete-conflicting-outputs
```

---

## UI Guidelines (IMPORTANT — read before writing any widget)

See `docs/UI_GUIDELINES.md` for full rules. Summary:
- **Blue (#2563EB) and white only.** No gradients, no rainbow accents.
- **No animations.** `flutter_animate` is NOT in pubspec. No `AnimatedContainer` unless functionally required.
- **No decorative Cards.** Use `ListTile` + `Divider` for lists.
- **TextButton preferred** over ElevatedButton. ElevatedButton only for the single primary CTA per screen.
- **No emoji** in UI text, buttons, or labels. Use `Icons.*` sparingly.
- **Dense layout.** 13px body text, tight padding, `isDense: true` on all inputs.
- **Gloves-friendly.** Min 44px tap targets — substation operators may wear gloves.

---

## Navigation Pattern

See `docs/NAVIGATION.md` for full spec. Summary:
- **Bottom Nav (5 tabs):** Logsheet | Work Orders | PTW | Defects | More
- **Tabs inside modules:** `DefaultTabController` + `TabBar` for sub-views
- **Drawer (hamburger):** Admin, Reports, Settings, Logout — role-gated
- **Web/Windows:** Left sidebar instead of bottom nav
- Implemented via `StatefulShellRoute` in go_router

---

## Database

Schema: `supabase/schema.sql` — run this in Supabase SQL Editor to set up.

Key tables:
- `tenants`, `org_units` (hierarchy), `user_profiles`, `user_role_assignments`
- `equipment` (asset master), `equipment_history` (Reg 2)
- `shift_logs`, `shift_readings` (Reg 19 daily log sheet)
- `ptw_requests` (Reg 9a/9b — 7-step PTW workflow)
- `defects` (Reg 7), `work_orders`
- `energy_readings` + `monthly_energy_balance` view (Reg 8)
- `tripping_events` (Reg 10), `stoppages` (Reg 11)
- `accident_reports` (CEA Reg 46)
- `audit_logs` (immutable — RLS blocks update/delete)

Supabase config: `lib/core/supabase/supabase_config.dart`
— replace placeholder URL and anon key before running.

---

## Folder Structure

```
lib/
  core/
    auth/           Supabase auth service, session management
    router/         GoRouter config (app_router.dart)
    theme/          AppTheme, AppColors (blue/white minimalist)
    supabase/       Supabase client config
    utils/          Formatters, validators
    errors/         Error types, exception handling
    constants/      AppConstants (operating limits, org levels)
  features/
    launchpad/      Home screen — authorized micro-app tiles
    iam/            User management, roles, permissions (admin)
    operations/     Logsheet, tripping, stoppage, messages
    ptw/            Permit to Work workflow + registers
    maintenance/    Work orders, scheduler, defects, equipment
    assets/         Asset master, history, documents
    energy/         Energy accounting, ABT, rostering
    safety/         Accident reports, compliance
    reports/        Dashboard, availability, SAIDI/SAIFI
  shared/
    widgets/        Reusable widgets (DataTable, StatusBadge, etc.)
    models/         Shared data models
    services/       Shared services (cache, sync)
    extensions/     Dart extensions
supabase/
  schema.sql        Full PostgreSQL schema — run once in Supabase
docs/
  TECH_STACK.md
  ARCHITECTURE.md
  UI_GUIDELINES.md
  NAVIGATION.md
  REGULATORY.md
  BUILD_STATUS.md
research_notes/     Regulatory research (UPPTCL, CEA, CERC, IEGC)
reports/            Generated research reports
```

---

## Regulatory Context (brief)

Full detail in `docs/REGULATORY.md` and `research_notes/`.

The ERP is built to comply with:
- **UPPTCL O&M Manual 2020** — 19 mandatory registers at every EHV substation
- **CEA Safety Regulations 2010** — PTW system (Reg 30), accident reporting (Reg 46)
- **CERC Metering Regulations 2006** — 15-min ABT blocks, meter accuracy Class 0.2S
- **IEGC 2010 (amended 2023)** — frequency bands, voltage limits, SLDC reporting
- **IEC 60076/60156/60599/60480/60255** — equipment test limits
- **IS 335, IS 3043** — transformer oil, earthing

Critical constants (in `AppConstants`):
- Transformer WTI alarm: 90°C, trip: 105°C
- Transformer OTI alarm: 85°C, trip: 95°C
- Frequency normal: 49.9–50.05 Hz; emergency below 49.0 Hz
- PTW lead time to SLDC: 24 hours minimum (planned outage)
- Energy meter reading: 8:00 AM daily (Register 8)
- Accident reporting to CEIG: within 24 hours (CEA Reg 46)

---

## Build Status

See `docs/BUILD_STATUS.md` for full task list.

**Completed (session 2026-10-02):**
- [x] Old Firebase app deleted
- [x] New Flutter project created (suberp, com.suberp)
- [x] All dependencies installed and resolving
- [x] Folder structure created (features, core, shared)
- [x] `supabase/schema.sql` — full PostgreSQL schema with RLS
- [x] `lib/core/theme/app_theme.dart` — minimalist blue/white theme
- [x] `lib/core/router/app_router.dart` — GoRouter with ShellRoute skeleton
- [x] `lib/core/constants/app_constants.dart`
- [x] `lib/core/supabase/supabase_config.dart`
- [x] `lib/main.dart` — Supabase init + Riverpod ProviderScope

**Next to build (in order):**
1. Auth flow — login screen, session guard, redirect logic
2. Launchpad — home screen with authorized micro-app tiles
3. Shell (bottom nav + drawer scaffold)
4. Shift Logsheet — highest daily use, Reg 19
5. PTW workflow — 7-step, statutory
6. Work Orders + Defects
7. Energy Account (Reg 8)
8. IAM (User Management, Roles, Permissions)
9. Reports & Dashboard

---

## Key Rules for This Project

1. Never add firebase_* packages — Firebase is gone, Supabase only
2. Never use flutter_animate or decorative animations
3. Always use TextButton unless it's the single primary CTA
4. Mobile app must be offline-capable — cache aggressively, batch writes
5. Never `select *` from Supabase — always name columns
6. Run `dart run build_runner build --delete-conflicting-outputs` after any @riverpod/@freezed change
7. Supabase URL/key are in `lib/core/supabase/supabase_config.dart` — never hardcode elsewhere
8. Every git commit must end with: `Co-Authored-By: Sanjay Kumar <fswdsanjay@gmail.com>`
