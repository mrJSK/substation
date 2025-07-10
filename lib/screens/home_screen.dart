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
import '../screens/equipment_hierarchy_selection_screen.dart';
import '../screens/substation_detail_screen.dart';
import '../screens/admin/reading_template_management_screen.dart';
import '../screens/energy_sld_screen.dart'; // NEW: Import the new screen
import '../screens/saved_sld_list_screen.dart'; // NEW: Import SavedSldListScreen

import '../utils/snackbar_utils.dart';
import 'substation_user_dashboard_screen.dart'; // NEW: Import the new substation user dashboard

class HomeScreen extends StatefulWidget {
  final AppUser appUser;

  const HomeScreen({super.key, required this.appUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // These state variables are primarily for hierarchy selection in admin dashboard
  // and might not be directly used for non-admin user's dashboard view.
  String? _selectedScreenStateName;
  String? _selectedScreenZoneId;
  String? _selectedScreenCircleId;
  String? _selectedScreenDivisionId;
  String? _selectedScreenSubdivisionId;

  // The state variables related to substation selection for logsheet dashboard
  // are now moved to SubstationUserDashboardScreen.

  @override
  void initState() {
    super.initState();
    // No specific loading for non-admin users here anymore,
    // as it's handled by SubstationUserDashboardScreen.
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
          title: const Text(
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
                style: const TextStyle(color: Colors.red),
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
    List<BottomNavigationBarItem> bottomNavItems =
        []; // This list is now functionally used only for Admin's conceptual bottom nav.
    int selectedIndex = 0;

    if (widget.appUser.role == UserRole.admin) {
      appBarTitle = 'Admin Dashboard';
      bodyContent = AdminDashboardScreen(adminUser: widget.appUser);
      // Admin dashboard might have its own bottom nav items, but for now, it's not explicitly used.
      // bottomNavItems is empty for admin, so bottomNavigationBar will be null.
    } else {
      appBarTitle = 'User Dashboard';
      // NEW: Directly use SubstationUserDashboardScreen for non-admin users
      bodyContent = SubstationUserDashboardScreen(currentUser: widget.appUser);

      // For non-admin users, their bottom navigation is now handled by the TabBar
      // inside SubstationUserDashboardScreen, so this BottomNavigationBar should be null.
      bottomNavItems = []; // Ensure it's empty for non-admin users
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
        // Removed logout button from AppBar actions
        actions: [],
      ),
      // ADD THIS DRAWER WIDGET
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.appUser.email,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  Text(
                    'Role: ${widget.appUser.role.toString().split('.').last}',
                    style:
                        (Theme.of(context).textTheme.bodyMedium ??
                                const TextStyle())
                            .copyWith(
                              // Changed line here
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.7),
                            ),
                  ),
                ],
              ),
            ),
            if (widget.appUser.role == UserRole.admin) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.rule),
                title: const Text('Reading Templates'),
                onTap: () {
                  Navigator.of(context).pop(); // Close the drawer
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const ReadingTemplateManagementScreen(),
                    ),
                  );
                },
              ),
              // NEW: Energy SLD entry for Admin
              ListTile(
                leading: const Icon(Icons.flash_on),
                title: const Text('Energy SLD'),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the drawer
                  // Allow admin to select substation for Energy SLD
                  final selectedSubstation =
                      await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  EquipmentHierarchySelectionScreen(
                                    currentUser: widget.appUser,
                                  ),
                            ),
                          )
                          as Substation?; // Expect a Substation object back
                  if (selectedSubstation != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EnergySldScreen(
                          substationId: selectedSubstation.id,
                          substationName: selectedSubstation.name,
                          currentUser: widget.appUser,
                        ),
                      ),
                    );
                  } else {
                    SnackBarUtils.showSnackBar(
                      context,
                      'No substation selected for Energy SLD.',
                      isError: true,
                    );
                  }
                },
              ),
              // NEW: Link to Saved SLD List Screen for Admin
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('View Saved SLDs'),
                onTap: () {
                  Navigator.of(context).pop(); // Close the drawer
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          SavedSldListScreen(currentUser: widget.appUser),
                    ),
                  );
                },
              ),
              const Divider(),
            ],
            // NEW: Energy SLD entry for SubstationUser & SubdivisionManager
            if (widget.appUser.role == UserRole.substationUser ||
                widget.appUser.role == UserRole.subdivisionManager) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.flash_on),
                title: const Text('Energy SLD'),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the drawer
                  // Logic to select substation for user roles (if multiple are accessible)
                  Substation? substationToView;
                  if (widget.appUser.assignedLevels != null &&
                      widget.appUser.assignedLevels!.containsKey(
                        'substationId',
                      )) {
                    // SubstationUser: directly use assigned substation
                    final substationDoc = await FirebaseFirestore.instance
                        .collection('substations')
                        .doc(widget.appUser.assignedLevels!['substationId'])
                        .get();
                    if (substationDoc.exists) {
                      substationToView = Substation.fromFirestore(
                        substationDoc,
                      );
                    }
                  } else if (widget.appUser.assignedLevels != null &&
                      widget.appUser.assignedLevels!.containsKey(
                        'subdivisionId',
                      )) {
                    // SubdivisionManager: allow selection from their subdivision
                    final selectedSubstation =
                        await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    EquipmentHierarchySelectionScreen(
                                      currentUser: widget.appUser,
                                    ),
                              ),
                            )
                            as Substation?; // Expect a Substation object back
                    substationToView = selectedSubstation;
                  }

                  if (substationToView != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EnergySldScreen(
                          substationId: substationToView!.id,
                          substationName: substationToView.name,
                          currentUser: widget.appUser,
                        ),
                      ),
                    );
                  } else {
                    SnackBarUtils.showSnackBar(
                      context,
                      'No substation assigned or selected for Energy SLD.',
                      isError: true,
                    );
                  }
                },
              ),
              // NEW: Link to Saved SLD List Screen for SubstationUser and SubdivisionManager
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('View Saved SLDs'),
                onTap: () {
                  Navigator.of(context).pop(); // Close the drawer
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          SavedSldListScreen(currentUser: widget.appUser),
                    ),
                  );
                },
              ),
            ],
            // Example Drawer item for logging out
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop(); // Close the drawer
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn()
                    .signOut(); // Also sign out from Google if used
                if (mounted) {
                  // Navigate back to AuthScreen and remove all previous routes
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
            // You can add more ListTile widgets here for other navigation options
            // based on the user's role if needed.
          ],
        ),
      ),
      body: bodyContent,
      bottomNavigationBar:
          (widget.appUser.role == UserRole.admin &&
              bottomNavItems.isNotEmpty) // Only show if admin AND has items
          ? BottomNavigationBar(
              items: bottomNavItems,
              currentIndex: selectedIndex,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.6),
            )
          : null, // Set to null for non-admin roles (and if admin but no items)
    );
  }
}
