import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// Bottom nav shell for mobile/tablet.
/// On web/Windows (width >= 720), switches to a left navigation rail.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    _TabItem(icon: Icons.book_outlined,      activeIcon: Icons.book,            label: 'Logsheet',  route: AppRoutes.logsheet),
    _TabItem(icon: Icons.build_outlined,     activeIcon: Icons.build,           label: 'Work Orders', route: AppRoutes.workOrders),
    _TabItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment,     label: 'PTW',       route: AppRoutes.ptwList),
    _TabItem(icon: Icons.report_outlined,    activeIcon: Icons.report,          label: 'Defects',   route: AppRoutes.defects),
    _TabItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view,       label: 'More',      route: AppRoutes.launchpad),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 720;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onTap,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              selectedIconTheme: IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
              unselectedIconTheme: const IconThemeData(color: Color(0xFF6B7280)),
              unselectedLabelTextStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              destinations: _tabs.map((t) => NavigationRailDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon),
                label: Text(t.label),
              )).toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          selectedIcon: Icon(t.activeIcon, color: AppColors.primary),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _TabItem({required this.icon, required this.activeIcon, required this.label, required this.route});
}
