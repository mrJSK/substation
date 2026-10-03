# GridERP Build Status

Last updated: 2026-10-03. Context: [CLAUDE.md](../CLAUDE.md).

## Done

### Foundation (backend) — live on Supabase project GridERP
- 14 domain migrations, consolidated per module (platform, org, IAM, experience, assets, operations, PTW, maintenance, energy, safety, notifications, reports, storage, semantic layer).
- Dynamic hierarchy (tenant levels, any depth, ragged trees, subtree moves) and cross-level sharing.
- WHO × WHAT × WHERE authorization with validity dates, standard role templates, role cloning, no-privilege-escalation guard.
- Micro-app catalog (18 T-codes) and dynamic forms (2 standard forms).
- Database-enforced PTW workflow, document numbering, energy net calculation, audit trail.
- API exposure locked down (anon has nothing; no TRUNCATE; internal functions revoked); advisors clean.
- Semantic layer for AI (comments on all business tables and KPI functions).
- Edge Functions deployed: `iam-admin-users`, `generate-work-orders`, `notify-deadlines`.
- Live smoke test passed (provisioning, scope, escalation guard, PTW order, numbering) — rolled back.

### Foundation (app)
- No code generation: Riverpod 3 hand-written providers, plain models.
- Session with offline-cached access profile; router guard; responsive shell (bottom nav / rail).
- Launchpad from `get_my_apps()` with T-code command box; `MicroAppHost` with access check.
- OR01 Org Structure (units tree, levels, sharing), SU01 Users (create, activate, assign roles with scope and validity), PFCG Roles (templates, copy, permission matrix), UI01 Forms and Apps (preview, customise, enable/disable).
- Dynamic form engine with alarm/trip limits and conditional fields.
- `flutter analyze` clean; unit tests for permission scope logic and form schema; `flutter build web` succeeds.

## Next (in order)

| # | Item | Notes |
|---|---|---|
| 1 | First tenant + admin account | Create the admin in Supabase Auth, then run `provision_tenant` (see API_REFERENCE). |
| 2 | Host the website | Deploy `build/web` (e.g. Vercel / Netlify / Cloudflare Pages); add the domain to Auth redirect URLs. |
| 3 | Schedule jobs | pg_cron + pg_net calling `generate-work-orders` (daily) and `notify-deadlines` (4-hourly) with the service-role JWT. |
| 4 | Unit context | "Current unit" picker for operational screens; cache equipment per unit. |
| 5 | AS01 Equipment Master | List/detail/history; technical params via dynamic forms per type. |
| 6 | OP01 Shift Logsheet | Uses `get_or_create_shift`, `TRANSFORMER_HOURLY` form, offline write queue (Hive) with batched upserts. |
| 7 | PT01 Permit to Work | Workflow UI over the DB state machine; Realtime for active permits. |
| 8 | MT01/MT02 Work orders and defects | |
| 9 | EN01/EN02 Energy | |
| 10 | RP01 Dashboard, SM20 Audit trail | |
| 11 | First-login password change, MFA for admins | |
| 12 | AI query (Edge Function + Claude, read-only tools) and pgvector document search | |

## Known gaps
- `iam-admin-users` sets a temporary password; forced change at first login is not built yet.
- Inactive users are blocked by the database but their Auth account is not banned.
- Availability is computed per unit only (subtree aggregation needs equipment-weighted logic).
