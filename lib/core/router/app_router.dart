import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/launchpad/presentation/launchpad_screen.dart';
import '../../features/iam/presentation/users_screen.dart';
import '../../features/iam/presentation/roles_screen.dart';
import '../../shared/widgets/app_shell.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const login     = '/login';
  static const launchpad = '/launchpad';

  // Operations
  static const logsheet  = '/ops/logsheet';
  static const tripping  = '/ops/tripping';
  static const stoppage  = '/ops/stoppage';
  static const messages  = '/ops/messages';

  // PTW
  static const ptwList   = '/ptw';
  static const ptwNew    = '/ptw/new';
  static const ptwDetail = '/ptw/:id';

  // Work Orders
  static const workOrders = '/wo';
  static const woNew      = '/wo/new';
  static const woDetail   = '/wo/:id';

  // Defects
  static const defects    = '/defects';

  // Maintenance
  static const maintenanceSchedule = '/maintenance';

  // Assets
  static const assetList   = '/assets';
  static const assetDetail = '/assets/:id';

  // Energy
  static const energyAccount = '/energy';
  static const abt           = '/energy/abt';

  // Reports
  static const dashboard   = '/reports/dashboard';
  static const availability = '/reports/availability';
  static const saidiSaifi  = '/reports/saidi-saifi';

  // IAM
  static const users       = '/iam/users';
  static const roles       = '/iam/roles';
  static const permissions = '/iam/permissions';

  // Safety
  static const accidentReport = '/safety/accident';
}

@riverpod
GoRouter appRouter(Ref ref) {
  // Listen to auth state so the router refreshes on sign-in / sign-out
  final authNotifier = _AuthListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.launchpad,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final goingToLogin = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !goingToLogin) return AppRoutes.login;
      if (isLoggedIn && goingToLogin)   return AppRoutes.launchpad;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),

      // Shell with bottom nav / side rail
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          // Branch 0 — Logsheet
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.logsheet, builder: (_, __) => const _Placeholder('Shift Logsheet')),
          ]),
          // Branch 1 — Work Orders
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.workOrders, builder: (_, __) => const _Placeholder('Work Orders')),
            GoRoute(path: AppRoutes.woNew,      builder: (_, __) => const _Placeholder('New Work Order')),
          ]),
          // Branch 2 — PTW
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.ptwList, builder: (_, __) => const _Placeholder('Permit to Work')),
            GoRoute(path: AppRoutes.ptwNew,  builder: (_, __) => const _Placeholder('New PTW')),
          ]),
          // Branch 3 — Defects
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.defects, builder: (_, __) => const _Placeholder('Defects')),
          ]),
          // Branch 4 — More (launchpad + everything else)
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.launchpad,  builder: (_, __) => const LaunchpadScreen()),
            GoRoute(path: AppRoutes.tripping,   builder: (_, __) => const _Placeholder('Tripping Register')),
            GoRoute(path: AppRoutes.stoppage,   builder: (_, __) => const _Placeholder('Stoppages')),
            GoRoute(path: AppRoutes.assetList,  builder: (_, __) => const _Placeholder('Assets')),
            GoRoute(path: AppRoutes.energyAccount, builder: (_, __) => const _Placeholder('Energy Account')),
            GoRoute(path: AppRoutes.dashboard,  builder: (_, __) => const _Placeholder('Dashboard')),
            GoRoute(path: AppRoutes.users,      builder: (_, __) => const UsersScreen()),
            GoRoute(path: AppRoutes.roles,      builder: (_, __) => const RolesScreen()),
          ]),
        ],
      ),
    ],
  );
}

// Makes GoRouter re-evaluate redirect when Supabase auth state changes
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Text('$title — coming soon',
          style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
