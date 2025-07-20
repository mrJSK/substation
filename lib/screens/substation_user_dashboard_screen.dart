// lib/screens/substation_user_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart'; // For Substation model
import '../../utils/snackbar_utils.dart';
import 'bay_readings_overview_screen.dart'; // Correct import for BayReadingsOverviewScreen
import 'tripping_shutdown_overview_screen.dart'; // Import TrippingShutdownOverviewScreen
import 'subdivision_asset_management_screen.dart'; // Import the new asset management screen

class SubstationUserDashboardScreen extends StatefulWidget {
  final AppUser currentUser;

  const SubstationUserDashboardScreen({super.key, required this.currentUser});

  @override
  State<SubstationUserDashboardScreen> createState() =>
      _SubstationUserDashboardScreenState();
}

class _SubstationUserDashboardScreenState
    extends State<SubstationUserDashboardScreen>
    with SingleTickerProviderStateMixin {
  Substation? _selectedSubstationForLogsheet;
  List<Substation> _accessibleSubstations = [];
  bool _isLoadingSubstations = true;

  late TabController _tabController;
  int _currentTabIndex = 0; // Track current tab index

  @override
  void initState() {
    super.initState();
    _loadAccessibleSubstations();

    // Initialize TabController
    // Ensure tabCount is calculated correctly before initializing _tabController
    // The tabCount determines the number of items in the TabBarView and BottomNavigationBar
    final int tabCount = widget.currentUser.role == UserRole.subdivisionManager
        ? 4 // Operations, Energy, Tripping & Shutdown, Assets
        : 3; // Operations, Energy, Tripping & Shutdown
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose(); // Dispose the controller
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  Future<void> _loadAccessibleSubstations() async {
    setState(() {
      _isLoadingSubstations = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('substations');

      // Filter substations based on user's role and assigned levels
      if (widget.currentUser.role == UserRole.subdivisionManager &&
          widget.currentUser.assignedLevels != null &&
          widget.currentUser.assignedLevels!.containsKey('subdivisionId')) {
        query = query.where(
          'subdivisionId',
          isEqualTo: widget.currentUser.assignedLevels!['subdivisionId'],
        );
      } else if (widget.currentUser.role == UserRole.substationUser &&
          widget.currentUser.assignedLevels != null &&
          widget.currentUser.assignedLevels!.containsKey('substationId')) {
        query = query.where(
          FieldPath.documentId,
          isEqualTo: widget.currentUser.assignedLevels!['substationId'],
        );
      } else {
        // Roles not explicitly handled or without assigned levels
        _accessibleSubstations = [];
        _isLoadingSubstations = false;
        return;
      }

      final snapshot = await query.orderBy('name').get();
      setState(() {
        _accessibleSubstations = snapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
        // Automatically select the substation if it's a SubstationUser with one assigned
        // OR if it's a Subdivision Manager with only one substation in their subdivision
        if ((widget.currentUser.role == UserRole.substationUser ||
                widget.currentUser.role == UserRole.subdivisionManager) &&
            _accessibleSubstations.length == 1) {
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

  @override
  Widget build(BuildContext context) {
    // Determine the number of tabs here, before the Scaffold, as it's needed for TabController
    final int tabCount = widget.currentUser.role == UserRole.subdivisionManager
        ? 4
        : 3;

    return Scaffold(
      // Removed the AppBar from here. The parent screen (HomeScreen) is expected
      // to provide the main AppBar. If this screen is the top-level,
      // you might want to add a custom header in the body.
      // For this request, the title "Substation Dashboard" is moved to the body.
      body: _isLoadingSubstations
          ? const Center(child: CircularProgressIndicator())
          : _accessibleSubstations.isEmpty && !_isLoadingSubstations
          ? Center(
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
                      'Welcome, ${widget.currentUser.email}!',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Role: ${widget.currentUser.role.toString().split('.').last}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade700,
                      ),
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
            )
          : Column(
              // Use Column here to hold the dropdown, title and TabBarView
              children: [
                // Added a Text widget for the title, as AppBar is removed.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 16.0,
                  ),
                  child: Text(
                    'Substation Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Substation Dropdown (conditionally shown based on tab and selection)
                if ((_currentTabIndex <
                        tabCount -
                            1) && // Hide for the last tab (Assets for SM, or Tripping for SU)
                    (_accessibleSubstations.length > 1 ||
                        _selectedSubstationForLogsheet == null))
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownSearch<Substation>(
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        menuProps: MenuProps(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                          hintText: 'Choose a substation to view details',
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
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Operations (Hourly) Tab
                      BayReadingsOverviewScreen(
                        substationId:
                            _selectedSubstationForLogsheet?.id ??
                            '', // Pass ID, handle null in screen
                        substationName:
                            _selectedSubstationForLogsheet?.name ??
                            'N/A', // Pass name, handle null
                        currentUser: widget.currentUser,
                        frequencyType: 'hourly',
                      ),
                      // Energy (Daily) Tab
                      BayReadingsOverviewScreen(
                        substationId: _selectedSubstationForLogsheet?.id ?? '',
                        substationName:
                            _selectedSubstationForLogsheet?.name ?? 'N/A',
                        currentUser: widget.currentUser,
                        frequencyType: 'daily',
                      ),
                      // Tripping & Shutdown Tab
                      TrippingShutdownOverviewScreen(
                        substationId: _selectedSubstationForLogsheet?.id ?? '',
                        substationName:
                            _selectedSubstationForLogsheet?.name ?? 'N/A',
                        currentUser: widget.currentUser,
                      ),
                      // NEW: Subdivision Manager's Asset Management Tab
                      if (widget.currentUser.role ==
                          UserRole.subdivisionManager)
                        SubdivisionAssetManagementScreen(
                          subdivisionId: widget
                              .currentUser
                              .assignedLevels!['subdivisionId']!,
                          currentUser: widget.currentUser,
                        ),
                    ],
                  ),
                ),
              ],
            ),
      // Moved TabBar content to bottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        // Removed 'controller: _tabController' as BottomNavigationBar does not have this parameter.
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
            _tabController.animateTo(index); // Animate to selected tab
          });
        },
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.access_time_filled),
            label: 'Operations',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.electric_meter),
            label: 'Energy',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Tripping & Shutdown',
          ),
          if (widget.currentUser.role == UserRole.subdivisionManager)
            const BottomNavigationBarItem(
              icon: Icon(Icons.construction),
              label: 'Assets',
            ),
        ],
      ),
    );
  }
}
