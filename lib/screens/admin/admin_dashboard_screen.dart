// lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'admin_hierarchy_screen.dart';
import 'master_equipment_management_screen.dart';
import 'user_management_screen.dart';
import 'reading_template_management_screen.dart';
import '../equipment_hierarchy_selection_screen.dart';
import 'bay_relationship_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppUser adminUser;
  final Widget? drawer;

  const AdminDashboardScreen({super.key, required this.adminUser, this.drawer});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      drawer: widget.drawer,
      body: _buildBody(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Admin Dashboard',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 32),
          _buildFunctionGrid(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final username = widget.adminUser.email.split('@').first;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.person,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $username',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage all aspects of Substation Manager Pro',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionGrid(ThemeData theme) {
    final functions = _getDashboardFunctions();

    return Column(
      children: [
        for (int i = 0; i < functions.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(child: _buildFunctionCard(functions[i], theme)),
                if (i + 1 < functions.length) ...[
                  const SizedBox(width: 16),
                  Expanded(child: _buildFunctionCard(functions[i + 1], theme)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFunctionCard(Map<String, dynamic> function, ThemeData theme) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => function['screen']),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(function['icon'], color: function['color'], size: 24),
            const SizedBox(height: 16),
            Text(
              function['title'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              function['subtitle'],
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDashboardFunctions() {
    return [
      {
        'title': 'Hierarchy',
        'subtitle': 'Manage zones, circles, divisions, substations',
        'icon': Icons.account_tree_outlined,
        'screen': const AdminHierarchyScreen(),
        'color': Colors.blue,
      },
      {
        'title': 'Users',
        'subtitle': 'Approve users and assign roles',
        'icon': Icons.people_outline,
        'screen': const UserManagementScreen(),
        'color': Colors.green,
      },
      {
        'title': 'Equipment',
        'subtitle': 'Define equipment templates',
        'icon': Icons.construction_outlined,
        'screen': const MasterEquipmentScreen(),
        'color': Colors.orange,
      },
      {
        'title': 'Templates',
        'subtitle': 'Define reading parameters for bays',
        'icon': Icons.rule_outlined,
        'screen': const ReadingTemplateManagementScreen(),
        'color': Colors.purple,
      },
      {
        'title': 'Substations',
        'subtitle': 'Browse substations and manage equipment',
        'icon': Icons.electrical_services_outlined,
        'screen': EquipmentHierarchySelectionScreen(
          currentUser: widget.adminUser,
        ),
        'color': Colors.indigo,
      },
      {
        'title': 'Relationships',
        'subtitle': 'Define relationships between bays',
        'icon': Icons.link,
        'screen': BayRelationshipManagementScreen(
          currentUser: widget.adminUser,
        ),
        'color': Colors.teal,
      },
      {
        'title': 'Export',
        'subtitle': 'Generate reports and data exports',
        'icon': Icons.download_outlined,
        'screen': const Center(
          child: Text('Export Data Screen (Coming Soon!)'),
        ),
        'color': Colors.red,
      },
    ];
  }
}
