# SubERP — Build Status & Roadmap

**Last updated:** 2026-10-02  
**Entry point:** See `CLAUDE.md` for full project context.

---

## Phase 1 — Foundation ✅ DONE

| Task | Status | Notes |
|------|--------|-------|
| Delete old Firebase Flutter app | DONE | |
| Create new Flutter project (suberp, com.suberp) | DONE | Flutter 3.47.5 / Dart 3.13.4 |
| Add all dependencies (Supabase, Riverpod, GoRouter, Drift, Hive) | DONE | `flutter pub get` passing |
| Feature folder structure | DONE | See CLAUDE.md |
| `lib/core/theme/app_theme.dart` | DONE | Blue/white minimalist, TextButton-first |
| `lib/core/router/app_router.dart` | DONE | GoRouter skeleton with ShellRoute, placeholder pages |
| `lib/core/constants/app_constants.dart` | DONE | Operating limits, org levels |
| `lib/core/supabase/supabase_config.dart` | DONE | Placeholder — needs real URL/key |
| `lib/main.dart` | DONE | Supabase init + Riverpod ProviderScope |
| `dart run build_runner build` | IN PROGRESS | Running in background; generates .g.dart files |
| CLAUDE.md + docs/ chain | DONE | |

## Phase 1B — Backend (Supabase) ✅ DONE

| Task | Status | Notes |
|------|--------|-------|
| `migrations/001_initial_schema.sql` | DONE | All 20 tables, enums, indexes |
| `migrations/002_triggers.sql` | DONE | Sequences, updated_at, SoD, audit, WO completion |
| `migrations/003_functions.sql` | DONE | 9 RPC functions (KPIs, helpers, shift upsert) |
| `migrations/004_rls_policies.sql` | DONE | Full org-scoped RLS, all tables |
| `migrations/005_seed.sql` | DONE | 8 system roles, 14 maintenance plan templates |
| `migrations/006_storage.sql` | DONE | 6 storage buckets with tenant-path RLS |
| `migrations/007_notifications.sql` | DONE | Notifications table for deadline alerts |
| `functions/generate-work-orders/index.ts` | DONE | Daily cron → auto WO from maintenance_schedules |
| `functions/notify-deadlines/index.ts` | DONE | 4-hourly: CEIG deadline, energy statement, PTW overrun |
| `supabase/config.toml` | DONE | Local dev config, cron schedules |

**To deploy backend:** Create a Supabase project → run each migration file in order in SQL Editor → deploy Edge Functions with `supabase functions deploy`.

## Phase 2 — Auth & Shell (NEXT)

| Task | Status | Notes |
|------|--------|-------|
| Login screen (email/password) | TODO | Supabase Auth PKCE |
| Session guard (redirect unauthenticated) | TODO | GoRouter redirect callback |
| User profile fetch on login | TODO | `user_profiles` + `user_role_assignments` |
| Bottom nav shell scaffold | TODO | `StatefulShellRoute` in GoRouter |
| Drawer/hamburger menu | TODO | Role-gated menu items |
| Launchpad home (micro-app tiles) | TODO | Show only authorized apps |
| Offline indicator widget | TODO | `connectivity_plus` |

## Phase 3 — Core Operations Modules

| Task | Status | Priority | Regulatory basis |
|------|--------|----------|-----------------|
| Shift Logsheet entry | TODO | Critical | UPPTCL Reg 19 |
| Hourly reading form (transformer/feeder) | TODO | Critical | Reg 19 |
| Shift handover screen | TODO | High | Reg 19 |
| Tripping entry (Reg 10) | TODO | Critical | Reg 10 |
| Stoppage register entry (Reg 11) | TODO | Critical | Reg 11 |
| SLDC message log (Reg 16a/b) | TODO | Medium | Reg 16a/16b |
| Defect reporting (Reg 7) | TODO | Critical | Reg 7 |

## Phase 4 — PTW (Permit to Work)

| Task | Status | Notes |
|------|--------|-------|
| 7-step PTW workflow screen | TODO | CEA Safety Reg 30 — statutory |
| Shutdown request form (Reg 9a) | TODO | |
| PTW issue form (Reg 9b) | TODO | SoD: issuer ≠ workman |
| Isolation checklist | TODO | |
| Earthing point entry (min 3 rods) | TODO | |
| PTW return & re-energization steps | TODO | |
| Active PTW realtime badge | TODO | Supabase Realtime |

## Phase 5 — Maintenance & Assets

| Task | Status | Notes |
|------|--------|-------|
| Equipment master list | TODO | |
| Equipment detail (Plant History — Reg 2) | TODO | |
| Maintenance plan templates | TODO | Monthly/Quarterly/Yearly per equipment type |
| Auto WO generation from maintenance plans | TODO | Supabase Edge Function (cron) |
| Work order list & detail | TODO | |
| WO completion with test results | TODO | Freezed schema per equipment type |
| DGA trend chart | TODO | fl_chart — C2H2 over time |

## Phase 6 — Energy Accounting

| Task | Status | Notes |
|------|--------|-------|
| Daily meter reading entry (8:00 AM) | TODO | Reg 8 |
| Monthly energy balance computation | TODO | Loss % = (A−B)/A × 100 |
| Max/Min load register (Reg 17) | TODO | Displayed in control room |
| ABT 15-min block viewer | TODO | CERC Metering Regs |
| Rostering register (Reg 15) | TODO | Load shedding schedule |

## Phase 7 — IAM (User & Permission Management)

| Task | Status | Notes |
|------|--------|-------|
| User list & creation | TODO | Supabase Auth + user_profiles |
| Role assignment (with org scope) | TODO | 3-axis RBAC |
| Permission matrix view | TODO | SAP PFCG equivalent |
| Authorization register (Reg 12) | TODO | Print PDF of authorized persons |
| Competency certificate management | TODO | CEA staff qualification |
| Time-limited access (valid_from/valid_to) | TODO | |

## Phase 8 — Reports & Compliance

| Task | Status | Notes |
|------|--------|-------|
| Availability % dashboard | TODO | (8760 − forced outage hrs) / 8760 |
| SAIDI / SAIFI trend | TODO | From stoppages table |
| AT&C loss trend | TODO | From energy_readings |
| Accident register (CEA Reg 46) | TODO | 24-hr CEIG notification alert |
| Statutory register PDF export | TODO | pdf + printing |
| Monthly SLDC report | TODO | Energy statement by 5th of month |

---

## Known Issues / Blockers

| Issue | Status |
|-------|--------|
| `supabase_config.dart` has placeholder URL/key | OPEN — needs real Supabase project |
| `app_router.g.dart` not yet generated | Pending `build_runner` completion |
| Font files not in `assets/fonts/` — pubspec references them | TODO: add Inter font files or switch to google_fonts |

---

## Architecture Notes for Next Session

- The `app_router.g.dart` is generated by `build_runner` (Riverpod annotation). If missing, run `dart run build_runner build --delete-conflicting-outputs`
- Supabase URL + anon key must be set in `lib/core/supabase/supabase_config.dart` before the app can run
- The Inter font in pubspec.yaml expects files in `assets/fonts/` — either add .ttf files there or remove the fonts section and use `google_fonts` package instead (already in deps)
- Schema in `supabase/schema.sql` is ready to run — paste into Supabase SQL Editor once project is created
