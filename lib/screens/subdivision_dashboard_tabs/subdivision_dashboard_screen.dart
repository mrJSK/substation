import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // NEW: For date formatting
import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart'; // For Substation model
import '../../models/app_state_data.dart'; // For AppStateData

// Import your new tab widgets
import 'operations_tab.dart';
import 'energy_tab.dart';
import 'tripping_tab.dart';
import 'reports_tab.dart';
import 'asset_management_tab.dart';

class SubdivisionDashboardScreen extends StatefulWidget {
  final AppUser currentUser;
  final String? selectedSubstationId;
  final Widget? drawer;

  const SubdivisionDashboardScreen({
    Key? key,
    required this.currentUser,
    this.selectedSubstationId,
    this.drawer,
  }) : super(key: key);

  @override
  State<SubdivisionDashboardScreen> createState() =>
      _SubdivisionDashboardScreenState();
}

class _SubdivisionDashboardScreenState extends State<SubdivisionDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Substation> _substations = []; // Keep track of substations for dropdown
  String? _currentSelectedSubstationId; // State for dropdown

  // NEW: Date range for dashboard tabs
  DateTime _dashboardStartDate = DateTime.now().subtract(
    const Duration(days: 7),
  );
  DateTime _dashboardEndDate = DateTime.now();

  final List<String> _tabs = [
    'Operations',
    'Energy',
    'Tripping',
    'Reports',
    'Asset Management',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _currentSelectedSubstationId = widget.selectedSubstationId;
    _fetchSubstationsForDropdown(); // Fetch substations needed for the dropdown
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubstationsForDropdown() async {
    final AppUser currentUser = widget.currentUser;
    if (currentUser.assignedLevels?['subdivisionId'] == null) {
      // Handle error or show a message
      return;
    }
    final subdivisionId = currentUser.assignedLevels!['subdivisionId'];
    try {
      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: subdivisionId)
          .orderBy('name')
          .get();

      if (!mounted) return;
      setState(() {
        _substations = substationsSnapshot.docs
            .map((doc) => Substation.fromFirestore(doc))
            .toList();
        if (_currentSelectedSubstationId == null && _substations.isNotEmpty) {
          _currentSelectedSubstationId = _substations.first.id;
        }
        // Update AppStateData here if _currentSelectedSubstationId changes
        if (_currentSelectedSubstationId != null) {
          final selectedSubstation = _substations.firstWhere(
            (s) => s.id == _currentSelectedSubstationId,
          );
          Provider.of<AppStateData>(
            context,
            listen: false,
          ).setSelectedSubstation(selectedSubstation);
        }
      });
    } catch (e) {
      print('Error fetching substations for dropdown: $e');
      // Show snackbar or handle error
    }
  }

  void _onSubstationChangedInDropdown(String? newSubstationId) {
    setState(() {
      _currentSelectedSubstationId = newSubstationId;
      if (newSubstationId != null) {
        final selectedSubstation = _substations.firstWhere(
          (s) => s.id == newSubstationId,
        );
        Provider.of<AppStateData>(
          context,
          listen: false,
        ).setSelectedSubstation(selectedSubstation);
      }
    });
  }

  // NEW: Date picker method for dashboard
  Future<void> _selectDashboardDate(
    BuildContext context,
    bool isStartDate,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _dashboardStartDate : _dashboardEndDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _dashboardStartDate = picked;
          if (_dashboardStartDate.isAfter(_dashboardEndDate)) {
            _dashboardEndDate = _dashboardStartDate;
          }
        } else {
          _dashboardEndDate = picked;
          if (_dashboardEndDate.isBefore(_dashboardStartDate)) {
            _dashboardStartDate = _dashboardEndDate;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.currentUser;

    final List<Widget> _screensContent = [
      OperationsTab(
        currentUser: currentUser,
        initialSelectedSubstationId: _currentSelectedSubstationId,
        // OperationsTab handles its own date range internally
      ),
      EnergyTab(
        currentUser: currentUser,
        initialSelectedSubstationId: _currentSelectedSubstationId,
        startDate: _dashboardStartDate, // Pass dashboard-wide start date
        endDate: _dashboardEndDate, // Pass dashboard-wide end date
      ),
      TrippingTab(
        currentUser: currentUser,
        startDate: _dashboardStartDate, // Pass dashboard-wide start date
        endDate: _dashboardEndDate, // Pass dashboard-wide end date
      ),
      ReportsTab(
        currentUser: currentUser,
        selectedSubstationId: _currentSelectedSubstationId,
        subdivisionId: currentUser.assignedLevels?['subdivisionId'] ?? '',
        startDate: _dashboardStartDate, // Pass dashboard-wide start date
        endDate: _dashboardEndDate, // Pass dashboard-wide end date
      ),
      if (currentUser.role == UserRole.subdivisionManager)
        AssetManagementTab(
          currentUser: currentUser,
          subdivisionId: currentUser.assignedLevels?['subdivisionId'] ?? '',
          selectedSubstationId: _currentSelectedSubstationId,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subdivision Dashboard'),
        centerTitle: true,
        leading: widget.drawer != null
            ? Builder(
                builder: (BuildContext context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).openAppDrawerTooltip,
                  );
                },
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [..._tabs.map((tab) => Tab(text: tab)).toList()],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
            onPressed: () async {
              final DateTime? pickedStartDate = await showDatePicker(
                context: context,
                initialDate: _dashboardStartDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (pickedStartDate != null) {
                final DateTime? pickedEndDate = await showDatePicker(
                  context: context,
                  initialDate: _dashboardEndDate,
                  firstDate:
                      pickedStartDate, // End date cannot be before start date
                  lastDate: DateTime.now(),
                );
                if (pickedEndDate != null) {
                  setState(() {
                    _dashboardStartDate = pickedStartDate;
                    _dashboardEndDate = pickedEndDate;
                  });
                }
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Text(
                '${DateFormat('dd.MMM').format(_dashboardStartDate)} - ${DateFormat('dd.MMM').format(_dashboardEndDate)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      drawer: widget.drawer,
      body: TabBarView(controller: _tabController, children: _screensContent),
    );
  }
}
