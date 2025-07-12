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
import '../screens/energy_sld_screen.dart';
import '../screens/saved_sld_list_screen.dart';

import '../utils/snackbar_utils.dart';
import 'substation_user_dashboard_screen.dart';

// NEW: Import SldEditorState
import '../state_management/sld_editor_state.dart';

class HomeScreen extends StatefulWidget {
  final AppUser appUser;

  // Define a static routeName for this screen
  static const String routeName = '/home'; // Recommended for named routes

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
    List<BottomNavigationBarItem> bottomNavItems = [];
    int selectedIndex = 0;

    if (widget.appUser.role == UserRole.admin) {
      appBarTitle = 'Admin Dashboard';
      bodyContent = AdminDashboardScreen(adminUser: widget.appUser);
    } else {
      appBarTitle = 'User Dashboard';
      bodyContent = SubstationUserDashboardScreen(currentUser: widget.appUser);
      bottomNavItems = [];
    }

    final appState = Provider.of<AppStateData>(context);

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
        actions: [],
      ),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.7),
                            ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                appState.themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                appState.themeMode == ThemeMode.dark
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                appState.toggleTheme();
                Navigator.of(context).pop();
              },
            ),
            if (widget.appUser.role == UserRole.admin) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.rule),
                title: const Text('Reading Templates'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const ReadingTemplateManagementScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flash_on),
                title: const Text('Energy SLD'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final selectedSubstation =
                      await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  EquipmentHierarchySelectionScreen(
                                    currentUser: widget.appUser,
                                  ),
                            ),
                          )
                          as Substation?;
                  if (selectedSubstation != null) {
                    // Removed local ChangeNotifierProvider for SldEditorState
                    // as it's now provided globally in main.dart
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
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('View Saved SLDs'),
                onTap: () {
                  Navigator.of(context).pop();
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
            if (widget.appUser.role == UserRole.substationUser ||
                widget.appUser.role == UserRole.subdivisionManager) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.flash_on),
                title: const Text('Energy SLD'),
                onTap: () async {
                  Navigator.of(context).pop();
                  Substation? substationToView;
                  if (widget.appUser.assignedLevels != null &&
                      widget.appUser.assignedLevels!.containsKey(
                        'substationId',
                      )) {
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
                    final selectedSubstation =
                        await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    EquipmentHierarchySelectionScreen(
                                      currentUser: widget.appUser,
                                    ),
                              ),
                            )
                            as Substation?;
                    substationToView = selectedSubstation;
                  }

                  if (substationToView != null) {
                    // Removed local ChangeNotifierProvider for SldEditorState
                    // as it's now provided globally in main.dart
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
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('View Saved SLDs'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          SavedSldListScreen(currentUser: widget.appUser),
                    ),
                  );
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut(); // Ensure Google sign-out too
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => AuthScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: bodyContent,
      bottomNavigationBar:
          // Check if bottomNavItems is not empty AND it's an admin role
          (widget.appUser.role == UserRole.admin && bottomNavItems.isNotEmpty)
          ? BottomNavigationBar(
              items: bottomNavItems,
              currentIndex: selectedIndex,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.6),
            )
          : null, // If not admin or bottomNavItems is empty, return null
    );
  }
}
