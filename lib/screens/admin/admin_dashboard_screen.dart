import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../screens/admin/admin_hierarchy_screen.dart';
// Import other admin management screens as they are created
// import 'package:substation/screens/admin/admin_user_management_screen.dart';
// import 'package:substation/screens/admin/master_equipment_management_screen.dart';
// import 'package:substation/screens/admin/export_data_screen.dart'; // For exporting data

class AdminDashboardScreen extends StatelessWidget {
  final AppUser adminUser;

  const AdminDashboardScreen({super.key, required this.adminUser});

  @override
  Widget build(BuildContext context) {
    // Define dashboard items (cards)
    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': 'Manage Hierarchy',
        'subtitle': 'Zones, Circles, Divisions, Substations',
        'icon': Icons.location_on,
        'screen': const AdminHierarchyScreen(),
        'color': Theme.of(context).colorScheme.primary, // Blue
      },
      {
        'title': 'User Management',
        'subtitle': 'Approve users, assign roles',
        'icon': Icons.people,
        'screen': const Center(
          child: Text('User Management Screen (Coming Soon!)'),
        ), // Placeholder
        'color': Theme.of(context).colorScheme.secondary, // Green
      },
      {
        'title': 'Master Equipment',
        'subtitle': 'Define equipment templates',
        'icon': Icons.construction,
        'screen': const Center(
          child: Text('Master Equipment Management (Coming Soon!)'),
        ), // Placeholder
        'color': Theme.of(context).colorScheme.tertiary, // Yellow
      },
      {
        'title': 'Export Data',
        'subtitle': 'Generate reports and data exports',
        'icon': Icons.download,
        'screen': const Center(
          child: Text('Export Data Screen (Coming Soon!)'),
        ), // Placeholder
        'color': Colors
            .redAccent
            .shade700, // A distinct red for export/critical actions
      },
      // Add more admin functions here as needed
    ];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card for Admin
            Card(
              elevation: 6, // Slightly higher elevation for the welcome card
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${adminUser.email.split('@').first.toUpperCase()}!', // Display part of email as name
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
                      value: 0.8, // Example value
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
                        'System Health: Good (80%)', // Example text
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

            // Stacked full-width Admin Functions Cards
            Text(
              'Admin Functions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Column(
              // Changed from GridView.builder to Column for stacking
              children: dashboardItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16.0,
                  ), // Spacing between cards
                  child: SizedBox(
                    // Use SizedBox to force full width with padding
                    width: MediaQuery.of(
                      context,
                    ).size.width, // Set width to screen width
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
            const SizedBox(height: 8), // Adjusted spacing after stacked cards
            // Example Quick Stats Section (can be populated with real data later)
            Text('Quick Stats', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  // Use Expanded to ensure each stat card takes available width
                  child: StatCard(
                    label: 'Total Zones',
                    value: '10', // Placeholder
                    icon: Icons.public,
                    iconColor: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // Use Expanded
                  child: StatCard(
                    label: 'Pending Approvals',
                    value: '3', // Placeholder
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
                  // Use Expanded
                  child: StatCard(
                    label: 'Total Substations',
                    value: '150', // Placeholder
                    icon: Icons.electrical_services,
                    iconColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // Use Expanded
                  child: StatCard(
                    label: 'Active Users',
                    value: '45', // Placeholder
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

// Reusable Widget for Dashboard Cards
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
            mainAxisSize: MainAxisSize
                .min, // crucial for preventing unbounded height issues
            children: [
              Icon(icon, size: 40, color: cardColor),
              const SizedBox(height: 12),
              // Changed from Flexible to a fixed number of lines if a simple Text widget
              // is not inside a Flexible, it will naturally wrap.
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2, // Allow title to wrap over two lines
                overflow: TextOverflow
                    .ellipsis, // Truncate with ellipsis if it exceeds 2 lines
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                maxLines: 2, // Allow subtitle to wrap over two lines
                overflow: TextOverflow.ellipsis, // Truncate with ellipsis
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable Widget for Quick Stat Cards
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
          mainAxisSize: MainAxisSize
              .min, // crucial for preventing unbounded height issues
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  // Label is inside a Row, so Expanded here is appropriate for horizontal flex
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1, // Keep label on single line
                    overflow: TextOverflow.ellipsis, // Truncate if too long
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // The value is also within a Column, so it should not be Expanded
            // directly unless the Column itself is constrained or has MainAxisSize.min.
            // Since we added MainAxisSize.min to the parent Column, a simple Text
            // will try to fit, and we can add maxLines/overflow.
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1, // Keep value on single line
              overflow: TextOverflow.ellipsis, // Truncate if too long
            ),
          ],
        ),
      ),
    );
  }
}
