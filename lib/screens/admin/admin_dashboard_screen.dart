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
  final Widget? drawer; // NEW: Add drawer property

  const AdminDashboardScreen({
    super.key,
    required this.adminUser,
    this.drawer,
  }); // NEW: Add drawer to constructor

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
        'screen': EquipmentHierarchySelectionScreen(
          currentUser: widget.adminUser,
        ),
        'color': Colors.indigo,
      },
      {
        'title': 'Bay Relationship Management',
        'subtitle':
            'Define relationships between bays (e.g., Transformer to Bus)',
        'icon': Icons.link,
        'screen': BayRelationshipManagementScreen(
          currentUser: widget.adminUser,
        ),
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
      appBar: AppBar(
        // ADDED AppBar
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        leading: Builder(
          // ADDED Builder for leading icon
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(
                  context,
                ).openDrawer(); // Access the parent Scaffold's drawer
              },
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            );
          },
        ),
      ),
      drawer: widget.drawer, // NEW: Use the passed drawer
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        Theme.of(context).colorScheme.background,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${widget.adminUser.email.split('@').first.toUpperCase()}!',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome to your Admin Control Panel. Manage all aspects of the Substation Manager Pro.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Admin Functions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600
                      ? 3
                      : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: MediaQuery.of(context).size.width > 600
                      ? 1.2
                      : 1.0,
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
      ),
    );
  }
}

class DashboardCard extends StatefulWidget {
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
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 36, color: widget.cardColor),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
