import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../screens/admin/admin_hierarchy_screen.dart';
import '../../screens/admin/master_equipment_management_screen.dart';
import '../../screens/substation_detail_screen.dart';
import '../../screens/equipment_hierarchy_selection_screen.dart';
import '../../screens/admin/user_management_screen.dart'; // Import the UserManagementScreen

class AdminDashboardScreen extends StatelessWidget {
  final AppUser adminUser;

  const AdminDashboardScreen({super.key, required this.adminUser});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': 'Manage Hierarchy',
        'subtitle': 'Zones, Circles, Divisions, Substations',
        'icon': Icons.location_on,
        'screen': const AdminHierarchyScreen(),
        'color': Theme.of(context).colorScheme.primary,
      },
      {
        'title': 'Master Equipment',
        'subtitle': 'Define equipment templates',
        'icon': Icons.construction,
        'screen': const MasterEquipmentScreen(),
        'color': Theme.of(context).colorScheme.tertiary,
      },
      // REMOVED: The "Create New Bay" card directly from Admin Dashboard
      // This is now handled through the "Manage Substations & Equipment" flow
      // {
      //   'title': 'Create New Bay',
      //   'subtitle': 'Add a new bay to a substation',
      //   'icon': Icons.add_box,
      //   'screen': BayCreationScreen(currentUser: adminUser),
      //   'color': Theme.of(context).colorScheme.secondary,
      // },
      {
        'title': 'Manage Substations & Equipment',
        'subtitle': 'Browse substations and manage bays/equipment',
        'icon': Icons.electrical_services,
        'screen': EquipmentHierarchySelectionScreen(currentUser: adminUser),
        'color': Colors.indigo,
      },
      {
        'title': 'User Management',
        'subtitle': 'Approve users, assign roles',
        'icon': Icons.people,
        'screen':
            const UserManagementScreen(), // Direct to UserManagementScreen
        'color': Theme.of(context).colorScheme.secondary,
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
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: 0.8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        'System Health: Good (80%)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
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
            Column(
              children: dashboardItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: DashboardCard(
                      title: item['title'],
                      subtitle: item['subtitle'],
                      icon: item['icon'],
                      cardColor: item['color'],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => item['screen'],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text('Quick Stats', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Zones',
                    value: '10',
                    icon: Icons.public,
                    iconColor: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    label: 'Pending Approvals',
                    value: '3',
                    icon: Icons.pending_actions,
                    iconColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Substations',
                    value: '150',
                    icon: Icons.electrical_services,
                    iconColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    label: 'Active Users',
                    value: '45',
                    icon: Icons.person_add_alt_1,
                    iconColor: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: cardColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
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

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
