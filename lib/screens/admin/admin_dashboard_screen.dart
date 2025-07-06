// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'admin_hierarchy_screen.dart';
import 'master_equipment_management_screen.dart';
import 'user_management_screen.dart';
import 'reading_template_management_screen.dart';
import '../equipment_hierarchy_selection_screen.dart';
import 'bay_relationship_management_screen.dart'; // Import the new screen

class AdminDashboardScreen extends StatelessWidget {
  final AppUser adminUser;

  const AdminDashboardScreen({super.key, required this.adminUser});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': 'Manage Hierarchy',
        'subtitle': 'Zones, Circles, Divisions, Substations',
        'icon': Icons.account_tree,
        'screen': const AdminHierarchyScreen(),
        'color': Theme.of(context).colorScheme.primary,
      },
      {
        'title': 'User Management',
        'subtitle': 'Approve users and assign roles',
        'icon': Icons.people,
        'screen': const UserManagementScreen(),
        'color': Theme.of(context).colorScheme.secondary,
      },
      {
        'title': 'Master Equipment',
        'subtitle': 'Define equipment templates',
        'icon': Icons.construction,
        'screen': const MasterEquipmentScreen(),
        'color': Theme.of(context).colorScheme.tertiary,
      },
      {
        'title': 'Reading Templates',
        'subtitle': 'Define reading parameters for bays',
        'icon': Icons.rule,
        'screen': const ReadingTemplateManagementScreen(),
        'color': Colors.cyan,
      },
      {
        'title': 'Manage Substations & Equipment',
        'subtitle': 'Browse substations and manage bays/equipment',
        'icon': Icons.electrical_services,
        'screen': EquipmentHierarchySelectionScreen(currentUser: adminUser),
        'color': Colors.indigo,
      },
      {
        'title': 'Bay Relationship Management', // NEW ITEM
        'subtitle':
            'Define relationships between bays (e.g., Transformer to Bus)',
        'icon': Icons.link,
        'screen': BayRelationshipManagementScreen(
          currentUser: adminUser,
        ), // Pass current user
        'color': Colors.purple,
      },
      {
        'title': 'Export Data',
        'subtitle': 'Generate reports and data exports',
        'icon': Icons.download,
        'screen': const Center(
          child: Text('Export Data Screen (Coming Soon!)'),
        ),
        'color': Colors.redAccent.shade700,
      },
    ];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${adminUser.email.split('@').first.toUpperCase()}!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome to your Admin Control Panel. Manage all aspects of the Substation Manager Pro.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Admin Functions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: dashboardItems.length,
              itemBuilder: (context, index) {
                final item = dashboardItems[index];
                return DashboardCard(
                  title: item['title'],
                  subtitle: item['subtitle'],
                  icon: item['icon'],
                  cardColor: item['color'],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => item['screen']),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color cardColor;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cardColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: cardColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
