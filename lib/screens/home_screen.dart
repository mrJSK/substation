// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart';
import '../screens/auth_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
// import '../screens/bay_creation_screen.dart'; // REMOVED
import '../screens/equipment_hierarchy_selection_screen.dart';
import '../screens/substation_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser appUser;

  const HomeScreen({super.key, required this.appUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedScreenStateName;
  String? _selectedScreenZoneId;
  String? _selectedScreenCircleId;
  String? _selectedScreenDivisionId;
  String? _selectedScreenSubdivisionId;

  @override
  void initState() {
    super.initState();
    if (widget.appUser.role == UserRole.subdivisionManager &&
        widget.appUser.assignedLevels != null &&
        widget.appUser.assignedLevels!.containsKey('subdivisionId')) {
      _selectedScreenSubdivisionId =
          widget.appUser.assignedLevels!['subdivisionId'];
    }
  }

  Widget _buildHierarchyExpansionTile<T extends HierarchyItem>({
    required String title,
    required IconData icon,
    required String collectionName,
    String? parentIdField,
    String? parentId,
    required AppUser currentUser,
    required Function(String? id) onSelectedId,
    Function(T item)? onFinalItemSelected,
  }) {
    if (parentIdField != null &&
        parentId == null &&
        currentUser.role == UserRole.admin) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          leading: Icon(icon, color: Colors.grey),
          title: Text(
            'Select a higher level first',
            style: TextStyle(color: Colors.grey),
          ),
          enabled: false,
        ),
      );
    }

    Query query = FirebaseFirestore.instance.collection(collectionName);

    if (parentIdField != null && parentId != null) {
      query = query.where(parentIdField, isEqualTo: parentId);
    }

    if (collectionName == 'substations' &&
        currentUser.role == UserRole.subdivisionManager &&
        currentUser.assignedLevels != null &&
        currentUser.assignedLevels!.containsKey('subdivisionId')) {
      query = query.where(
        'subdivisionId',
        isEqualTo: currentUser.assignedLevels!['subdivisionId'],
      );
    }

    query = query.orderBy('name');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              title: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              leading: CircularProgressIndicator(strokeWidth: 2),
              title: Text('Loading...'),
            ),
          );
        }

        final items = snapshot.data!.docs
            .map((doc) {
              if (collectionName == 'zones') return Zone.fromFirestore(doc);
              if (collectionName == 'circles') return Circle.fromFirestore(doc);
              if (collectionName == 'divisions')
                return Division.fromFirestore(doc);
              if (collectionName == 'subdivisions')
                return Subdivision.fromFirestore(doc);
              if (collectionName == 'substations')
                return Substation.fromFirestore(doc);
              return null;
            })
            .whereType<T>()
            .toList();

        if (items.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              title: Text(
                'No $title found.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
              enabled: false,
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 2,
          child: ExpansionTile(
            initiallyExpanded:
                collectionName == 'substations' &&
                (currentUser.role == UserRole.subdivisionManager),
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            children: items.map((item) {
              final isSubstation = (item is Substation);
              return ListTile(
                title: Text(item.name),
                leading: isSubstation
                    ? const Icon(Icons.electrical_services)
                    : const Icon(Icons.folder_open),
                onTap: () {
                  if (isSubstation) {
                    onFinalItemSelected?.call(item);
                  } else {
                    setState(() {
                      onSelectedId(item.id);
                    });
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    String appBarTitle;
    List<BottomNavigationBarItem> bottomNavItems = [];
    int selectedIndex = 0;

    if (widget.appUser.role == UserRole.admin) {
      appBarTitle = 'Admin Dashboard';
      bodyContent = AdminDashboardScreen(adminUser: widget.appUser);
      bottomNavItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      ];
    } else {
      appBarTitle = 'Dashboard';
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome, ${widget.appUser.email}!',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Role: ${widget.appUser.role.toString().split('.').last}',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            if (widget.appUser.role == UserRole.subdivisionManager)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EquipmentHierarchySelectionScreen(
                        currentUser: widget.appUser,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.electrical_services),
                label: const Text('Manage My Substations'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Your specific dashboard features are coming soon!',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
      bottomNavItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.schedule),
          label: 'Operations',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.electric_meter),
          label: 'Energy',
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: true,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: bodyContent,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Substation Manager Pro',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.appUser.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    'Role: ${widget.appUser.role.toString().split('.').last}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            if (widget.appUser.role == UserRole.admin ||
                widget.appUser.role == UserRole.subdivisionManager)
              ListTile(
                leading: const Icon(Icons.add_box),
                title: const Text(
                  'Create New Bay (via Hierarchy)',
                ), // Updated text to clarify flow
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // Directs to hierarchy selection, then Add Bay via SubstationDetailScreen
                      builder: (context) => EquipmentHierarchySelectionScreen(
                        currentUser: widget.appUser,
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.electrical_services),
              title: const Text(
                'Manage Equipment & Substations',
              ), // Consolidated option in drawer
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EquipmentHierarchySelectionScreen(
                      currentUser: widget.appUser,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            if (widget.appUser.role == UserRole.admin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin Dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  if (appBarTitle != 'Admin Dashboard') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            AdminDashboardScreen(adminUser: widget.appUser),
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          (bottomNavItems.isNotEmpty && widget.appUser.role != UserRole.admin)
          ? BottomNavigationBar(
              items: bottomNavItems,
              currentIndex: selectedIndex,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.6),
            )
          : null,
    );
  }
}
