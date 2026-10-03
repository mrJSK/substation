# GridERP — Project Context

The single entry point for anyone (human or AI) joining this project. Read this
first; follow the links for depth.

---

## 1. What we are building

**GridERP** is a multi-tenant SaaS ERP for power utilities — transmission,
distribution and generation companies and load dispatch centres. It covers
substation **operations and maintenance**: shift logsheets, Permit to Work,
equipment and maintenance, defects, energy accounting, safety and reliability
reporting, mapped to Indian statutory registers (CEA, CERC, IEGC, state O&M
manuals). It is a product to license to utilities, built to SAP-level
standards: configurable per customer, auditable, secure by default.

| Product | Platform | Users |
|---|---|---|
| Field app | Flutter Android (iOS later) | Operators, shift engineers, JEs in substations |
| Control-room app | Flutter Windows | Substation control rooms |
| Web portal | Flutter Web | Engineers, managers, administrators |

One Flutter codebase, three targets.

## 2. Why it is built this way

| Decision | Reason |
|---|---|
| **SaaS, multi-tenant** | One deployment serves many utilities. Every business row carries `tenant_id`, enforced by Row Level Security. |
| **Dynamic hierarchy** | Every utility structures itself differently (Zone/Circle/Division/Substation/Bay vs Region/Zone/Circle/…). Levels are tenant data, never code. |
| **Who × What × Where permissions** | SAP-grade authorization: a role (what) granted to a user (who) at an org unit and optionally everything below it (where), with validity dates. |
| **Cross-level data sharing** | Real grids cross org boundaries (SLDC reads a substation, a tie-line substation is shared by two circles). |
| **Micro-apps with T-codes** | Like SAP transactions (SU01, PFCG …): every function is a launchable app, granted by permission, switchable per tenant, reachable by typing its code. |
| **Dynamic UI (server-defined forms)** | Logsheet and equipment forms differ per utility. Forms are JSON in the database, so a customer changes them without an app release. |
| **Offline-first, low API cost** | The previous Firebase app was shut down because of API cost. Reference data and access are cached on the device; writes are batched; no polling. |
| **Security in the database** | Every rule (scope, workflow steps, no privilege escalation, segregation of duties) is enforced in PostgreSQL, so no client — app, API script or AI agent — can bypass it. |
| **AI-ready** | A semantic layer (plain-English comments on every table/column) lets AI assistants answer natural-language questions; AI always queries as the signed-in user, so the same security applies. |
| **Team-ready modularity** | Each business domain is a separate module (database file + Flutter feature) owned by one team, with explicit contracts between them. |

## 3. How — technology stack

| Layer | Technology | Why this, and what we rejected |
|---|---|---|
| UI | **Flutter 3.47 / Dart 3.13** | One codebase for Android, Windows and Web. |
| State | **Riverpod 3 (flutter_riverpod 3.4), hand-written providers** | Testable, compile-safe DI and async state. **No code generation**: riverpod_generator/freezed/build_runner hung and broke with newer Dart analyzers (Oct 2026), slowed Windows builds and added a build step for every team. |
| Models | **Plain Dart classes** with `fromJson` | No generator dependency; tolerant JSON readers in `lib/core/json.dart`. |
| Navigation | **go_router 14** with `StatefulShellRoute` | Bottom nav / rail with per-tab history; deep links per micro-app (`/home/app/SU01`). |
| Backend | **Supabase**: PostgreSQL 17 + PostgREST + Auth + Storage + Edge Functions | Relational data, RLS, SQL functions and auto-generated REST API; replaced Firebase. |
| Server logic | **PostgreSQL functions and triggers** first, **Edge Functions (Deno/TypeScript)** only for what SQL cannot do (creating auth users, scheduled jobs) | Rules live next to the data and apply to every client. |
| Offline cache | **Hive CE** (JSON strings, no adapters) | Works on Android, Windows and Web (IndexedDB). Drift was dropped (code generation, no web-first need yet). |
| Hierarchy queries | **ltree** materialized paths | "Everything under X" is one indexed operator: `path <@ x.path`. |
| PDF / charts | pdf + printing, fl_chart | Statutory registers, KPI trends. |

**Never add:** `firebase_*`, `flutter_animate`, `build_runner` / any code generator, the service-role key in the client.

## 4. Architecture at a glance

```
Flutter app (lib/)                              Supabase (supabase/)
  app/        composition: router, shell,         migrations/  one file per domain module
              T-code registry, micro-app host       0100 platform      tenants, numbering, audit
  core/       cross-cutting: cache, errors,         0200 org_hierarchy levels, units, sharing
              navigation, JSON, Supabase client     0300 iam           users, roles, permissions,
  shared/     reusable widgets                                         access functions, RLS
  features/   one folder per team-owned module      0350 experience    micro-apps, dynamic forms
    auth/       session, access profile             0400 assets … 0900 safety  (domain modules)
    launchpad/  home + T-code box                   1000 notifications, 1100 reports,
    org/        OR01 org structure                  1200 storage, 1300 semantic layer (AI)
    iam/        SU01 users, PFCG roles            functions/   Edge Functions (+ _shared/)
    forms/      dynamic form engine, UI01
```

Each feature folder: `data/` (Supabase calls) → `domain/` (models) →
`application/` (Riverpod providers) → `presentation/` (screens).
Features never import another feature's `data/` or `application/` internals;
public contracts are named explicitly (e.g. `org/presentation/org_unit_picker.dart`,
`auth/application/session_controller.dart`, `forms/data/forms_repository.dart#formDefinitionProvider`).

Full detail: **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** ·
API contract for frontend teams: **[docs/API_REFERENCE.md](docs/API_REFERENCE.md)** ·
Navigation: [docs/NAVIGATION.md](docs/NAVIGATION.md) ·
UI rules: [docs/UI_GUIDELINES.md](docs/UI_GUIDELINES.md) ·
Regulations: [docs/REGULATORY.md](docs/REGULATORY.md) ·
Progress: **[docs/BUILD_STATUS.md](docs/BUILD_STATUS.md)**

## 5. Environments and commands

- Supabase project **GridERP**, ref `ciznlknixpddqwrbvyvc`, region ap-northeast-1. Linked via `supabase link`.
- Client config: `lib/core/supabase/supabase_config.dart` (URL + publishable key only; override with `--dart-define`).

```bash
flutter pub get
flutter analyze && flutter test          # must be clean before every commit
flutter run -d chrome                    # web
flutter build web --release              # website build → build/web

supabase db push --linked                # apply new migrations
supabase db advisors --linked            # security/performance lint — keep clean
supabase functions deploy --use-api      # deploy Edge Functions
```

Migrations are append-only once shared: add a new timestamped file
(`YYYYMMDDHHMMSS_<module>_<change>.sql`), never edit an applied one
(the initial set was consolidated on 2026-10-03 before any customer data existed).

## 6. Rules for every change

1. Business rules go in the database (constraint, trigger, RLS, function) — the app only mirrors them for UX.
2. New table ⇒ RLS policies + grants via defaults + a `comment on` entry in the semantic layer.
3. Never `select *`; name columns. Postgrest `.order()` defaults to descending — always pass `ascending:`.
4. Nothing hierarchy-specific in code: use `org_levels` / `org_tree`, `org_unit_id`, and ltree paths.
5. Limits and form fields belong in `ui_forms`, not Dart constants.
6. New screen ⇒ a T-code row in `app_catalog` + one line in `lib/app/micro_app_registry.dart`.
7. Offline: cache reference data (`LocalCache`), batch writes, no polling; Realtime only for live PTW status/alerts.
8. UI: blue/white, no animations, TextButton-first, ListTile + Divider over cards, dense, 44 px targets, no emoji.
9. Every git commit ends with `Co-Authored-By: Sanjay Kumar <fswdsanjay@gmail.com>`.
