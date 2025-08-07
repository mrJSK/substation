// lib/screens/subdivision_dashboard_tabs/subdivision_dashboard_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../models/app_state_data.dart';
import '../../widgets/modern_app_drawer.dart';
import 'create_report_template_screen.dart';
import 'operations_tab.dart';
import 'energy_tab.dart';
import 'subdivision_asset_management_screen.dart';
import 'tripping_tab.dart';

class SubdivisionDashboardScreen extends StatefulWidget {
  final AppUser currentUser;

  const SubdivisionDashboardScreen({Key? key, required this.currentUser})
    : super(key: key);

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

  final List<TabData> _tabs = [
    TabData('Operations', Icons.settings, Colors.blue),
    TabData('Energy', Icons.electrical_services, Colors.green),
    TabData('Tripping', Icons.warning, Colors.orange),
    TabData(
      'Reports',
      Icons.assessment,
      Colors.purple,
    ), // Keep the same name and icon
    TabData('Asset Management', Icons.business, Colors.indigo),
  ];

  @override
  void initState() {
    super.initState();
    print('🔍 DEBUG: SubdivisionDashboardScreen initState called');
    print('🔍 DEBUG: Current user: ${widget.currentUser.email}');
    final tabCount = widget.currentUser.role == UserRole.subdivisionManager
        ? _tabs.length
        : _tabs.length - 1; // Exclude Asset Management for non-managers
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 DEBUG: SubdivisionDashboardScreen build called');
    final theme = Theme.of(context);
    final appState = Provider.of<AppStateData>(context);
    final accessibleSubstations = appState.accessibleSubstations;
    Substation? selectedSubstation = appState.selectedSubstation;

    print(
      '🔍 DEBUG: Accessible substations count: ${accessibleSubstations.length}',
    );
    print(
      '🔍 DEBUG: Selected substation: ${selectedSubstation?.name ?? 'null'}',
    );

    // Auto-select first substation if none selected
    if (selectedSubstation == null && accessibleSubstations.isNotEmpty) {
      selectedSubstation = accessibleSubstations.first;
      print(
        '🔍 DEBUG: Auto-selecting first substation: ${selectedSubstation.name}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.setSelectedSubstation(selectedSubstation!);
      });
    }

    if (selectedSubstation == null) {
      return _buildNoSubstationState(theme);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(
        theme,
        selectedSubstation,
        accessibleSubstations,
        appState,
      ),
      body: Column(
        children: [
          _buildTabBar(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _buildTabViews(selectedSubstation),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeData theme,
    Substation selectedSubstation,
    List<Substation> accessibleSubstations,
    AppStateData appState,
  ) {
    print(
      '🔍 DEBUG: Building AppBar with selected substation: ${selectedSubstation.name}',
    );
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      title: Row(
        children: [
          // Fixed substation selector in app bar
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Substation>(
                        value: selectedSubstation,
                        items: accessibleSubstations.map((substation) {
                          return DropdownMenuItem<Substation>(
                            value: substation,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: Text(
                                substation.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (Substation? newValue) {
                          print(
                            '🔍 DEBUG: Dropdown changed to: ${newValue?.name}',
                          );
                          if (newValue != null) {
                            appState.setSelectedSubstation(newValue);
                          }
                        },
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 8,
                        menuMaxHeight: 300,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return accessibleSubstations.map((
                            Substation substation,
                          ) {
                            return Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                substation.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildDateRangeChip(theme),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
        onPressed: () {
          print('🔍 DEBUG: Menu button pressed in SubdivisionDashboard');
          ModernAppDrawer.show(context, widget.currentUser);
        },
      ),
    );
  }

  Widget _buildDateRangeChip(ThemeData theme) {
    return InkWell(
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.secondary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 16,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              '${DateFormat('dd.MMM').format(_dashboardStartDate)} - ${DateFormat('dd.MMM').format(_dashboardEndDate)}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    final visibleTabs = widget.currentUser.role == UserRole.subdivisionManager
        ? _tabs
        : _tabs.where((tab) => tab.label != 'Asset Management').toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: visibleTabs.map((tab) => _buildCustomTab(tab)).toList(),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.primary.withOpacity(0.1),
        ),
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        padding: const EdgeInsets.all(8),
        tabAlignment: TabAlignment.start,
      ),
    );
  }

  Widget _buildCustomTab(TabData tabData) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tabData.icon, size: 18),
            const SizedBox(width: 8),
            Text(tabData.label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSubstationState(ThemeData theme) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
          onPressed: () {
            ModernAppDrawer.show(context, widget.currentUser);
          },
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Substations Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading substations or no accessible substations found. Please contact your administrator.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabViews(Substation selectedSubstation) {
    final List<Widget> views = [
      OperationsTab(
        currentUser: widget.currentUser,
        initialSelectedSubstationId: selectedSubstation.id,
        substationId: selectedSubstation.id,
        startDate: _dashboardStartDate,
        endDate: _dashboardEndDate,
      ),
      EnergyTab(
        currentUser: widget.currentUser,
        initialSelectedSubstationId: selectedSubstation.id,
        substationId: selectedSubstation.id,
        startDate: _dashboardStartDate,
        endDate: _dashboardEndDate,
      ),
      TrippingTab(
        currentUser: widget.currentUser,
        substationId: selectedSubstation.id,
        startDate: _dashboardStartDate,
        endDate: _dashboardEndDate,
      ),
      // REPLACED: ReportsTab with GenerateCustomReportScreen
      GenerateCustomReportScreen(
        startDate: _dashboardStartDate,
        endDate: _dashboardEndDate,
      ),
    ];

    if (widget.currentUser.role == UserRole.subdivisionManager) {
      views.add(
        SubdivisionAssetManagementScreen(
          subdivisionId:
              widget.currentUser.assignedLevels?['subdivisionId'] ?? '',
          currentUser: widget.currentUser,
        ),
      );
    }

    return views;
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _dashboardStartDate,
        end: _dashboardEndDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dashboardStartDate = picked.start;
        _dashboardEndDate = picked.end;
      });
    }
  }
}

class TabData {
  final String label;
  final IconData icon;
  final Color color;

  TabData(this.label, this.icon, this.color);
}
