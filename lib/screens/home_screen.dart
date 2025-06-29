// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart'; // Needed for DropdownSearch

import '../models/user_model.dart';
import '../models/hierarchy_models.dart'; // Needed for Substation model
import '../models/app_state_data.dart';
import '../screens/auth_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/equipment_hierarchy_selection_screen.dart';
import '../screens/substation_detail_screen.dart';
import '../screens/admin/reading_template_management_screen.dart';
import '../screens/logsheet_entry_screen.dart';
import '../utils/snackbar_utils.dart'; // Import the LogsheetEntryScreen

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

  // New state variables for the user's logsheet dashboard
  Substation? _selectedSubstationForLogsheet;
  List<Substation> _accessibleSubstations = [];
  bool _isLoadingSubstations = true;

  @override
  void initState() {
    super.initState();
    if (widget.appUser.role == UserRole.admin) {
      // No special substation loading for admin, they see the admin dashboard directly
    } else {
      _loadAccessibleSubstations();
    }
  }

  Future<void> _loadAccessibleSubstations() async {
    setState(() {
      _isLoadingSubstations = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('substations');

      // Filter substations based on user's role and assigned levels
      if (widget.appUser.role == UserRole.subdivisionManager &&
          widget.appUser.assignedLevels != null &&
          widget.appUser.assignedLevels!.containsKey('subdivisionId')) {
        query = query.where(
          'subdivisionId',
          isEqualTo: widget.appUser.assignedLevels!['subdivisionId'],
        );
      } else if (widget.appUser.role == UserRole.substationUser &&
          widget.appUser.assignedLevels != null &&
          widget.appUser.assignedLevels!.containsKey('substationId')) {
        query = query.where(
          FieldPath.documentId,
          isEqualTo: widget.appUser.assignedLevels!['substationId'],
        );
      } else if (widget.appUser.role == UserRole.admin) {
        // Admins can see all, but they have a separate dashboard.
        // This case is mostly for future expansion if admin also needs a direct substation selection here.
        // For now, they'll always see AdminDashboardScreen.
      } else {
        // Roles like pending, or managers without assigned levels, won't load any
        _accessibleSubstations = [];
        _isLoadingSubstations = false;
        return;
      }

      final snapshot = await query.orderBy('name').get();
      setState(() {
        _accessibleSubstations = snapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
        if (_accessibleSubstations.length == 1) {
          _selectedSubstationForLogsheet = _accessibleSubstations.first;
        }
      });
    } catch (e) {
      print("Error loading accessible substations: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load substations: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isLoadingSubstations = false;
      });
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
      appBarTitle = 'User Dashboard';
      if (_isLoadingSubstations) {
        bodyContent = const Center(child: CircularProgressIndicator());
      } else if (_accessibleSubstations.isEmpty) {
        bodyContent = Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                const Text(
                  'No substations assigned or found for your role. Please contact your administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // User has accessible substations, show dropdown and then tabs
        bodyContent = Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownSearch<Substation>(
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      labelText: 'Search Substation',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Substation',
                    hintText: 'Choose a substation to view logsheets',
                    prefixIcon: const Icon(Icons.electrical_services),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                itemAsString: (Substation s) => s.name,
                selectedItem: _selectedSubstationForLogsheet,
                items: _accessibleSubstations,
                onChanged: (Substation? newValue) {
                  setState(() {
                    _selectedSubstationForLogsheet = newValue;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a Substation' : null,
              ),
            ),
            if (_selectedSubstationForLogsheet != null)
              Expanded(
                child: DefaultTabController(
                  length: 3, // Hourly, Daily, Tripping/Shutdown
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        tabs: const [
                          Tab(
                            text: 'Hourly Readings',
                            icon: Icon(Icons.access_time),
                          ),
                          Tab(
                            text: 'Daily Readings',
                            icon: Icon(Icons.calendar_today),
                          ),
                          Tab(
                            text: 'Tripping & Shutdown',
                            icon: Icon(Icons.warning),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Hourly Readings Tab
                            LogsheetEntryScreen(
                              substationId: _selectedSubstationForLogsheet!.id,
                              substationName:
                                  _selectedSubstationForLogsheet!.name,
                              currentUser: widget.appUser,
                            ),
                            // Daily Readings Tab
                            LogsheetEntryScreen(
                              substationId: _selectedSubstationForLogsheet!.id,
                              substationName:
                                  _selectedSubstationForLogsheet!.name,
                              currentUser: widget.appUser,
                            ),
                            // Tripping & Shutdown Tab (Placeholder)
                            Center(
                              child: Text(
                                'Tripping & Shutdown features coming soon!',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }
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
            // Add "Manage Reading Templates" for admin
            if (widget.appUser.role == UserRole.admin)
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('Manage Reading Templates'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const ReadingTemplateManagementScreen(),
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
