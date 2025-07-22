// lib/screens/subdivision_dashboard_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.currentUser;
    // final appState = Provider.of<AppStateData>(context); // Not directly used in build now, but used in callbacks

    final List<Widget> _screensContent = [
      OperationsTab(
        currentUser: currentUser,
        initialSelectedSubstationId: _currentSelectedSubstationId,
        onRefreshParent: _fetchSubstationsForDropdown,
      ),
      EnergyTab(
        currentUser: currentUser,
        initialSelectedSubstationId: _currentSelectedSubstationId,
      ),
      TrippingTab(
        currentUser: currentUser,
        selectedSubstationId: _currentSelectedSubstationId,
      ),
      ReportsTab(
        currentUser: currentUser,
        selectedSubstationId: _currentSelectedSubstationId,
        subdivisionId: currentUser.assignedLevels?['subdivisionId'] ?? '',
      ),
      if (currentUser.role == UserRole.subdivisionManager)
        AssetManagementTab(
          currentUser: currentUser,
          subdivisionId: currentUser.assignedLevels?['subdivisionId'] ?? '',
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
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      drawer: widget.drawer,
      body: TabBarView(controller: _tabController, children: _screensContent),
      // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      // REMOVE THE floatingActionButton HERE
      // floatingActionButton: _tabController.index == _tabs.indexOf('Operations')
      //     ? FloatingActionButton.extended(
      //         onPressed: () {
      //           Navigator.of(context).pushNamed(CreateReportTemplateScreen.routeName);
      //         },
      //         label: const Text('Create Report Template'),
      //         icon: const Icon(Icons.add),
      //       )
      //     : null,
      // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    );
  }
}
