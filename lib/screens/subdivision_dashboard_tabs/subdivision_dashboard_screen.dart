// lib/screens/subdivision_dashboard_tabs/subdivision_dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../models/app_state_data.dart';
import 'operations_tab.dart';
import 'energy_tab.dart';
import 'tripping_tab.dart';
import 'reports_tab.dart';
import 'asset_management_tab.dart';

class SubdivisionDashboardScreen extends StatefulWidget {
  final AppUser currentUser;
  final Widget? drawer;

  const SubdivisionDashboardScreen({
    Key? key,
    required this.currentUser,
    this.drawer,
  }) : super(key: key);

  @override
  State<SubdivisionDashboardScreen> createState() =>
      _SubdivisionDashboardScreenState();
}

class _SubdivisionDashboardScreenState extends State<SubdivisionDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final AppStateData appState = Provider.of<AppStateData>(context);
    final AppUser currentUser = widget.currentUser;
    final List<Substation> accessibleSubstations =
        appState.accessibleSubstations;

    Substation? selectedSubstation = appState.selectedSubstation;

    if (selectedSubstation == null && accessibleSubstations.isNotEmpty) {
      selectedSubstation = accessibleSubstations.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.setSelectedSubstation(selectedSubstation!);
      });
    }

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Ensure selectedSubstation is not null before accessing its properties for required arguments
    // If selectedSubstation is still null here, it means no substations are accessible or loaded yet.
    if (selectedSubstation == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Loading substations or no accessible substations found.',
          ),
        ),
      );
    }

    final List<Widget> _screensContent = [
      OperationsTab(
        currentUser: currentUser,
        initialSelectedSubstationId: selectedSubstation.id,
        substationId: selectedSubstation.id, // Pass required substationId
        startDate: _dashboardStartDate, // Pass required startDate
        endDate: _dashboardEndDate, // Pass required endDate
      ),
      EnergyTab(
        currentUser: currentUser,
        initialSelectedSubstationId: selectedSubstation.id,
        substationId: selectedSubstation.id, // Pass required substationId
        startDate: _dashboardStartDate, // Pass required startDate
        endDate: _dashboardEndDate, // Pass required endDate
      ),
      TrippingTab(
        currentUser: currentUser,
        substationId: selectedSubstation.id, // Pass required substationId
        startDate: _dashboardStartDate, // Pass required startDate
        endDate: _dashboardEndDate, // Pass required endDate
      ),
      ReportsTab(
        currentUser: currentUser,
        selectedSubstationId: selectedSubstation.id,
        subdivisionId: currentUser.assignedLevels?['subdivisionId'] ?? '',
        substationId: selectedSubstation.id, // Pass required substationId
        startDate: _dashboardStartDate, // Pass required startDate
        endDate: _dashboardEndDate, // Pass required endDate
      ),
      if (currentUser.role == UserRole.subdivisionManager)
        AssetManagementTab(
          currentUser: currentUser,
          subdivisionId: currentUser.assignedLevels?['subdivisionId'] ?? '',
          selectedSubstationId: selectedSubstation.id,
          substationId: selectedSubstation.id, // Pass required substationId
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
          tabs: currentUser.role == UserRole.subdivisionManager
              ? [..._tabs.map((tab) => Tab(text: tab)).toList()]
              : _tabs
                    .where((tab) => tab != 'Asset Management')
                    .map((tab) => Tab(text: tab))
                    .toList(),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.date_range),
        //     tooltip: 'Select Date Range',
        //     onPressed: () async {
        //       final DateTime? pickedStartDate = await showDatePicker(
        //         context: context,
        //         initialDate: _dashboardStartDate,
        //         firstDate: DateTime(2000),
        //         lastDate: DateTime.now(),
        //       );
        //       if (pickedStartDate != null) {
        //         final DateTime? pickedEndDate = await showDatePicker(
        //           context: context,
        //           initialDate: _dashboardEndDate,
        //           firstDate: pickedStartDate,
        //           lastDate: DateTime.now(),
        //         );
        //         if (pickedEndDate != null) {
        //           setState(() {
        //             _dashboardStartDate = pickedStartDate;
        //             _dashboardEndDate = pickedEndDate;
        //           });
        //         }
        //       }
        //     },
        //   ),
        //   Padding(
        //     padding: const EdgeInsets.only(right: 8.0),
        //     child: Center(
        //       child: Text(
        //         '${DateFormat('dd.MMM').format(_dashboardStartDate)} - ${DateFormat('dd.MMM').format(_dashboardEndDate)}',
        //         style: Theme.of(
        //           context,
        //         ).textTheme.bodySmall?.copyWith(color: Colors.white),
        //       ),
        //     ),
        //   ),
        // ],
      ),
      drawer: widget.drawer,
      body: Column(
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: DropdownButtonFormField<Substation>(
          //     value: selectedSubstation,
          //     decoration: const InputDecoration(
          //       labelText: 'Select Substation',
          //       border: OutlineInputBorder(),
          //     ),
          //     items: accessibleSubstations.map((substation) {
          //       return DropdownMenuItem<Substation>(
          //         value: substation,
          //         child: Text(substation.name),
          //       );
          //     }).toList(),
          //     onChanged: (Substation? newValue) {
          //       if (newValue != null) {
          //         appState.setSelectedSubstation(newValue);
          //       }
          //     },
          //   ),
          // ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _screensContent,
            ),
          ),
        ],
      ),
    );
  }
}
