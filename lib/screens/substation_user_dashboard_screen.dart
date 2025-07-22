// lib/screens/substation_user_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import for DateFormat

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart'; // For Substation model
import '../../utils/snackbar_utils.dart';
import 'bay_readings_overview_screen.dart'; // Correct import for BayReadingsOverviewScreen
import 'tripping_shutdown_overview_screen.dart'; // Import TrippingShutdownOverviewScreen
import 'subdivision_asset_management_screen.dart'; // Import the new asset management screen
import 'equipment_hierarchy_selection_screen.dart'; // For Energy SLD navigation
import 'energy_sld_screen.dart'; // For Energy SLD navigation
import '../../controllers/sld_controller.dart'; // For Energy SLD navigation
import 'saved_sld_list_screen.dart'; // For Saved SLD navigation

class SubstationUserDashboardScreen extends StatefulWidget {
  final AppUser currentUser;
  final Widget? drawer;

  const SubstationUserDashboardScreen({
    super.key,
    required this.currentUser,
    this.drawer,
  });

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

  // Date state for all relevant tabs
  DateTime _singleDate = DateTime.now(); // For Substation User
  DateTime _startDate = DateTime.now().subtract(
    const Duration(days: 7),
  ); // For Subdivision Manager
  DateTime _endDate = DateTime.now(); // For Subdivision Manager

  @override
  void initState() {
    super.initState();
    _loadAccessibleSubstations();

    final int tabCount = widget.currentUser.role == UserRole.subdivisionManager
        ? 4 // Operations, Energy, Tripping & Shutdown, Assets
        : 3; // Operations, Energy, Tripping & Shutdown
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
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
    if (!mounted) return;
    setState(() {
      _isLoadingSubstations = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('substations');

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
        _accessibleSubstations = [];
        if (mounted) {
          setState(() {
            _isLoadingSubstations = false;
          });
        }
        return;
      }

      final snapshot = await query.orderBy('name').get();
      if (mounted) {
        setState(() {
          _accessibleSubstations = snapshot.docs
              .map((doc) => Substation.fromFirestore(doc))
              .toList();
          if (_accessibleSubstations.length >= 1) {
            _selectedSubstationForLogsheet = _accessibleSubstations.first;
          }
        });
      }
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
      if (mounted) {
        setState(() {
          _isLoadingSubstations = false;
        });
      }
    }
  }

  // Date picker method for Subdivision Manager (range selection)
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // Date picker method for Substation User (single date selection)
  Future<void> _selectSingleDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _singleDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _singleDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int tabCount = widget.currentUser.role == UserRole.subdivisionManager
        ? 4
        : 3;

    final bool isSubdivisionManager =
        widget.currentUser.role == UserRole.subdivisionManager;
    final bool showDatePickers =
        (_currentTabIndex == 0 ||
        _currentTabIndex == 1 ||
        _currentTabIndex == 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Substation Dashboard'),
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
            icon: const Icon(Icons.flash_on),
            tooltip: 'Energy SLD',
            onPressed: () async {
              Substation? substationToView;
              if (widget.currentUser.assignedLevels != null &&
                  widget.currentUser.assignedLevels!.containsKey(
                    'substationId',
                  )) {
                final substationDoc = await FirebaseFirestore.instance
                    .collection('substations')
                    .doc(widget.currentUser.assignedLevels!['substationId'])
                    .get();
                if (substationDoc.exists) {
                  substationToView = Substation.fromFirestore(substationDoc);
                }
              }

              if (substationToView != null && mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider<SldController>(
                      create: (context) => SldController(
                        substationId: substationToView!.id,
                        transformationController: TransformationController(),
                      ),
                      child: EnergySldScreen(
                        substationId: substationToView!.id,
                        substationName: substationToView.name,
                        currentUser: widget.currentUser,
                      ),
                    ),
                  ),
                );
              } else if (mounted) {
                SnackBarUtils.showSnackBar(
                  context,
                  'No substation assigned for Energy SLD.',
                  isError: true,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Saved SLDs',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SavedSldListScreen(currentUser: widget.currentUser),
                ),
              );
            },
          ),
        ],
      ),
      drawer: widget.drawer,
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
              children: [
                // Substation Dropdown (always at the top)
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
                // Conditional Date Pickers
                if (showDatePickers)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: isSubdivisionManager
                        ? Row(
                            // Date Range for Subdivision Manager
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: Text(
                                    'From: ${DateFormat('yyyy-MM-dd').format(_startDate)}',
                                  ),
                                  trailing: const Icon(Icons.calendar_today),
                                  onTap: () => _selectDateRange(context),
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  title: Text(
                                    'To: ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                                  ),
                                  trailing: const Icon(Icons.calendar_today),
                                  onTap: () => _selectDateRange(context),
                                ),
                              ),
                            ],
                          )
                        : ListTile(
                            // Single Date for Substation User
                            title: Text(
                              'Date: ${DateFormat('yyyy-MM-dd').format(_singleDate)}',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => _selectSingleDate(context),
                          ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Operations (Hourly) Tab
                      BayReadingsOverviewScreen(
                        substationId: _selectedSubstationForLogsheet?.id ?? '',
                        substationName:
                            _selectedSubstationForLogsheet?.name ?? 'N/A',
                        currentUser: widget.currentUser,
                        frequencyType: 'hourly',
                        // Pass appropriate date(s) based on role
                        startDate: isSubdivisionManager
                            ? _startDate
                            : _singleDate,
                        endDate: isSubdivisionManager
                            ? _endDate
                            : _singleDate, // For SU, endDate is same as startDate
                      ),
                      // Energy (Daily) Tab
                      BayReadingsOverviewScreen(
                        substationId: _selectedSubstationForLogsheet?.id ?? '',
                        substationName:
                            _selectedSubstationForLogsheet?.name ?? 'N/A',
                        currentUser: widget.currentUser,
                        frequencyType: 'daily',
                        // Pass appropriate date(s) based on role
                        startDate: isSubdivisionManager
                            ? _startDate
                            : _singleDate,
                        endDate: isSubdivisionManager
                            ? _endDate
                            : _singleDate, // For SU, endDate is same as startDate
                      ),
                      // Tripping & Shutdown Tab
                      TrippingShutdownOverviewScreen(
                        substationId: _selectedSubstationForLogsheet?.id ?? '',
                        substationName:
                            _selectedSubstationForLogsheet?.name ?? 'N/A',
                        currentUser: widget.currentUser,
                        // Pass appropriate date(s) based on role
                        startDate: isSubdivisionManager
                            ? _startDate
                            : _singleDate,
                        endDate: isSubdivisionManager
                            ? _endDate
                            : _singleDate, // For SU, endDate is same as startDate
                        // Substation user can only close, not create.
                        // Admin/SM can create.
                        canCreateTrippingEvents:
                            widget.currentUser.role ==
                                UserRole.subdivisionManager ||
                            widget.currentUser.role == UserRole.admin,
                      ),
                      // Subdivision Manager's Asset Management Tab
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
            _tabController.animateTo(index);
          });
        },
        type: BottomNavigationBarType.fixed,
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
