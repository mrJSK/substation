import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/routes.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/launchpad/presentation/launchpad_screen.dart';
import 'app_shell.dart';
import 'micro_app_host.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final signedIn = session.value != null;
      final atLogin = state.matchedLocation == Routes.login;
      if (session.isLoading && !session.hasValue) return null; // restoring session at startup
      if (!signedIn) return atLogin ? null : Routes.login;
      if (atLogin) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, _) => const LaunchpadScreen(),
              routes: [
                GoRoute(path: 'app/:code', builder: (_, state) => MicroAppHost(code: state.pathParameters['code']!.toUpperCase())),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.logsheet, builder: (_, _) => const MicroAppHost(code: 'OP01'))]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.workOrders, builder: (_, _) => const MicroAppHost(code: 'MT01'))]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.ptw, builder: (_, _) => const MicroAppHost(code: 'PT01'))]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.defects, builder: (_, _) => const MicroAppHost(code: 'MT02'))]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
