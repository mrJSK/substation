# Navigation

## Shell

| Width | Pattern |
|---|---|
| < 720 px (phones) | Bottom navigation bar |
| ≥ 720 px (tablets, Windows, web) | Left navigation rail |

Tabs (fixed order): **Home** · Logsheet (OP01) · Work Orders (MT01) · PTW (PT01) · Defects (MT02).
Implemented with go_router `StatefulShellRoute.indexedStack` in `lib/app/router.dart`;
each tab keeps its own back stack. Tabs a user has no permission for show an
access message instead of the app.

## Home (launchpad)

- Micro-app tiles grouped by module, built from `get_my_apps()` (only what the user may open).
- **T-code box** in the app bar: type `SU01`, `OR01`, … and press Enter.
- Account menu: refresh my access, sign out.
- Offline banner when access is served from the device cache.

## Routes

| Route | Screen |
|---|---|
| `/login` | Sign in |
| `/home` | Launchpad |
| `/home/app/:code` | Any micro-app by T-code (deep-linkable) |
| `/logsheet`, `/work-orders`, `/ptw`, `/defects` | Tab apps |

Open apps with `openMicroApp(context, code)` (`lib/core/navigation/routes.dart`);
it routes tab apps to their tab and everything else to `/home/app/:code`.

## Inside an app

- Sub-views: `DefaultTabController` + `TabBar` (e.g. OR01: Units · Levels · Sharing).
- Detail pages: `Navigator.push` within the current tab.
- Create/edit: bottom sheet (`showSheet`) with Cancel/Save text buttons.

## Guard

The router redirects to `/login` when there is no session profile and away
from `/login` once signed in. It refreshes when `sessionProvider` changes
(sign-in, sign-out, token expiry, access reload).
