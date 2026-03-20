import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_state_data.dart';
import '../../models/hierarchy_models.dart';
import '../../models/user_model.dart';
import '../subdivision_dashboard_tabs/energy_tab.dart';
import '../subdivision_dashboard_tabs/operations_tab.dart';
import '../subdivision_dashboard_tabs/overview.dart';
import '../subdivision_dashboard_tabs/subdivision_asset_management_screen.dart';
import '../subdivision_dashboard_tabs/tripping_tab.dart';
import 'windows_sidebar.dart';

class WindowsSubdivisionShell extends StatefulWidget {
  final AppUser currentUser;

  const WindowsSubdivisionShell({super.key, required this.currentUser});

  @override
  State<WindowsSubdivisionShell> createState() =>
      _WindowsSubdivisionShellState();
}

class _WindowsSubdivisionShellState extends State<WindowsSubdivisionShell> {
  int _selectedIndex = 0;

  List<SidebarNavItem> get _navItems {
    final items = [
      const SidebarNavItem('Overview', Icons.show_chart_rounded, Colors.teal),
      const SidebarNavItem(
          'Operations', Icons.settings_rounded, Colors.blue),
      const SidebarNavItem(
          'Energy', Icons.electrical_services_rounded, Colors.green),
      const SidebarNavItem(
          'Tripping & Shutdown', Icons.warning_rounded, Colors.orange),
    ];
    if (widget.currentUser.role == UserRole.subdivisionManager) {
      items.add(const SidebarNavItem(
          'Asset Management', Icons.business_rounded, Colors.indigo));
    }
    return items;
  }

  List<Widget> _buildTabViews(List<Substation> substations) {
    final views = <Widget>[
      OverviewScreen(
        currentUser: widget.currentUser,
        accessibleSubstations: substations,
      ),
      OperationsTab(
        currentUser: widget.currentUser,
        accessibleSubstations: substations,
      ),
      EnergyTab(
        currentUser: widget.currentUser,
        accessibleSubstations: substations,
      ),
      TrippingTab(
        currentUser: widget.currentUser,
        accessibleSubstations: substations,
      ),
    ];
    if (widget.currentUser.role == UserRole.subdivisionManager) {
      views.add(SubdivisionAssetManagementScreen(
        subdivisionId:
            widget.currentUser.assignedLevels?['subdivisionId'] ?? '',
        currentUser: widget.currentUser,
      ));
    }
    return views;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appState = Provider.of<AppStateData>(context);
    final substations = appState.accessibleSubstations;
    final navItems = _navItems;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F2F5),
      body: Row(
        children: [
          WindowsSidebar(
            currentUser: widget.currentUser,
            navItems: navItems,
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => setState(() => _selectedIndex = i),
            title: 'Subdivision Manager',
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          Expanded(
            child: substations.isEmpty
                ? _buildNoSubstationState(theme, isDark)
                : IndexedStack(
                    index: _selectedIndex,
                    children: _buildTabViews(substations),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubstationState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_off_rounded,
            size: 64,
            color: isDark ? Colors.white30 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Substations Available',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading substations or no accessible substations found.\nPlease contact your administrator.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
