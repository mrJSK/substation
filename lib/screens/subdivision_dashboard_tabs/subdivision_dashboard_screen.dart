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

  final List<TabData> _tabs = [
    TabData('Operations', Icons.settings, Colors.blue),
    TabData('Energy', Icons.electrical_services, Colors.green),
    TabData('Tripping', Icons.warning, Colors.orange),
    TabData('Reports', Icons.assessment, Colors.purple),
    TabData('Asset Management', Icons.business, Colors.indigo),
  ];

  @override
  void initState() {
    super.initState();
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
    final theme = Theme.of(context);
    final appState = Provider.of<AppStateData>(context);
    final accessibleSubstations = appState.accessibleSubstations;
    Substation? selectedSubstation = appState.selectedSubstation;

    // Auto-select first substation if none selected
    if (selectedSubstation == null && accessibleSubstations.isNotEmpty) {
      selectedSubstation = accessibleSubstations.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.setSelectedSubstation(selectedSubstation!);
      });
    }

    if (selectedSubstation == null) {
      return _buildNoSubstationState(theme);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(theme, selectedSubstation),
      drawer: widget.drawer,
      body: Column(
        children: [
          _buildSubstationSelector(
            theme,
            appState,
            accessibleSubstations,
            selectedSubstation,
          ),
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
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subdivision Dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            selectedSubstation.name,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
      leading: widget.drawer != null
          ? Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : null,
      actions: [_buildDateRangeChip(theme), const SizedBox(width: 16)],
    );
  }

  Widget _buildDateRangeChip(ThemeData theme) {
    return InkWell(
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              '${DateFormat('dd.MMM').format(_dashboardStartDate)} - ${DateFormat('dd.MMM').format(_dashboardEndDate)}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubstationSelector(
    ThemeData theme,
    AppStateData appState,
    List<Substation> accessibleSubstations,
    Substation selectedSubstation,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.location_on,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Substation',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<Substation>(
                    value: selectedSubstation,
                    items: accessibleSubstations.map((substation) {
                      return DropdownMenuItem(
                        value: substation,
                        child: Text(
                          substation.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (Substation? newValue) {
                      if (newValue != null) {
                        appState.setSelectedSubstation(newValue);
                      }
                    },
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    final visibleTabs = widget.currentUser.role == UserRole.subdivisionManager
        ? _tabs
        : _tabs.where((tab) => tab.label != 'Asset Management').toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      ReportsTab(
        currentUser: widget.currentUser,
        selectedSubstationId: selectedSubstation.id,
        subdivisionId:
            widget.currentUser.assignedLevels?['subdivisionId'] ?? '',
        substationId: selectedSubstation.id,
        startDate: _dashboardStartDate,
        endDate: _dashboardEndDate,
      ),
    ];

    if (widget.currentUser.role == UserRole.subdivisionManager) {
      views.add(
        AssetManagementTab(
          currentUser: widget.currentUser,
          subdivisionId:
              widget.currentUser.assignedLevels?['subdivisionId'] ?? '',
          selectedSubstationId: selectedSubstation.id,
          substationId: selectedSubstation.id,
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
