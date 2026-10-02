import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

// Route names — use these constants everywhere instead of string literals
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const launchpad = '/launchpad';

  // IAM
  static const users = '/iam/users';
  static const roles = '/iam/roles';
  static const permissions = '/iam/permissions';

  // Operations
  static const logsheet = '/ops/logsheet';
  static const tripping = '/ops/tripping';
  static const stoppage = '/ops/stoppage';
  static const messages = '/ops/messages';

  // PTW
  static const ptwList = '/ptw';
  static const ptwNew = '/ptw/new';
  static const ptwDetail = '/ptw/:id';

  // Work Orders
  static const workOrders = '/wo';
  static const woNew = '/wo/new';
  static const woDetail = '/wo/:id';

  // Defects
  static const defects = '/defects';

  // Maintenance scheduler
  static const maintenanceSchedule = '/maintenance';

  // Assets
  static const assetList = '/assets';
  static const assetDetail = '/assets/:id';

  // Energy
  static const energyAccount = '/energy';
  static const abt = '/energy/abt';

  // Reports
  static const dashboard = '/reports/dashboard';
  static const availability = '/reports/availability';
  static const saidiSaifi = '/reports/saidi-saifi';

  // Safety
  static const accidentReport = '/safety/accident';
}

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const _PlaceholderPage('Login'),
      ),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.launchpad,
            builder: (context, state) => const _PlaceholderPage('Launchpad'),
          ),
          GoRoute(
            path: AppRoutes.logsheet,
            builder: (context, state) => const _PlaceholderPage('Shift Logsheet'),
          ),
          GoRoute(
            path: AppRoutes.ptwList,
            builder: (context, state) => const _PlaceholderPage('Permit to Work'),
          ),
          GoRoute(
            path: AppRoutes.workOrders,
            builder: (context, state) => const _PlaceholderPage('Work Orders'),
          ),
          GoRoute(
            path: AppRoutes.energyAccount,
            builder: (context, state) => const _PlaceholderPage('Energy Account'),
          ),
          GoRoute(
            path: AppRoutes.assetList,
            builder: (context, state) => const _PlaceholderPage('Assets'),
          ),
          GoRoute(
            path: AppRoutes.users,
            builder: (context, state) => const _PlaceholderPage('User Management'),
          ),
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const _PlaceholderPage('Dashboard'),
          ),
        ],
      ),
    ],
  );
}

// ── Temporary placeholder widgets (replaced module by module) ──────────────

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    // TODO: Check Supabase session → redirect to launchpad or login
    Future.microtask(
      () => context.go(AppRoutes.launchpad),
    );
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title — coming soon',
            style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
