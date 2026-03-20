import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_hierarchy_screen.dart';
import '../admin/master_equipment_management_screen.dart';
import '../admin/reading_template_management_screen.dart';
import '../admin/upload_master_data.dart';
import '../admin/user_management_screen.dart';
import 'windows_sidebar.dart';

class WindowsAdminShell extends StatefulWidget {
  final AppUser adminUser;

  const WindowsAdminShell({super.key, required this.adminUser});

  @override
  State<WindowsAdminShell> createState() => _WindowsAdminShellState();
}

class _WindowsAdminShellState extends State<WindowsAdminShell> {
  int _selectedIndex = 0;
  final _navigatorKey = GlobalKey<NavigatorState>();

  static const _navItems = [
    SidebarNavItem(
        'Dashboard', Icons.dashboard_rounded, Colors.blue),
    SidebarNavItem(
        'User Management', Icons.people_rounded, Colors.teal),
    SidebarNavItem(
        'System Hierarchy', Icons.account_tree_rounded, Colors.indigo),
    SidebarNavItem(
        'Equipment Templates', Icons.construction_rounded, Colors.orange),
    SidebarNavItem(
        'Reading Templates', Icons.rule_rounded, Colors.purple),
    SidebarNavItem(
        'Upload Master Data', Icons.upload_file_rounded, Colors.green),
  ];

  void _selectItem(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _navigatorKey.currentState?.pushAndRemoveUntil(
      _buildRoute(index),
      (route) => false,
    );
  }

  Route<dynamic> _buildRoute(int index) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => _buildScreenForIndex(index),
      transitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  Widget _buildScreenForIndex(int index) {
    switch (index) {
      case 0:
        return AdminDashboardScreen(adminUser: widget.adminUser);
      case 1:
        return const UserManagementScreen();
      case 2:
        return const AdminHierarchyScreen();
      case 3:
        return const MasterEquipmentScreen();
      case 4:
        return const ReadingTemplateManagementScreen();
      case 5:
        return const UploadMasterDataScreen();
      default:
        return AdminDashboardScreen(adminUser: widget.adminUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F2F5),
      body: Row(
        children: [
          WindowsSidebar(
            currentUser: widget.adminUser,
            navItems: _navItems,
            selectedIndex: _selectedIndex,
            onItemSelected: _selectItem,
            title: 'Admin Console',
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          Expanded(
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (_) => _buildRoute(0),
            ),
          ),
        ],
      ),
    );
  }
}
