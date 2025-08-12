import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/app_state_data.dart';
import '../../models/hierarchy_models.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';
import 'substation_user_operations_tab.dart';
import 'substation_user_energy_tab.dart';
import 'substation_user_tripping_tab.dart';

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
    with TickerProviderStateMixin {
  Substation? _selectedSubstationForLogsheet;
  List<Substation> _accessibleSubstations = [];
  bool _isLoadingSubstations = true;
  late AnimationController _animationController;
  late TabController _tabController;
  int _currentTabIndex = 0;
  DateTime _singleDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadAccessibleSubstations();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  Future<void> _loadAccessibleSubstations() async {
    setState(() => _isLoadingSubstations = true);

    try {
      final appStateData = Provider.of<AppStateData>(context, listen: false);
      final user = appStateData.currentUser;

      if (user == null) {
        SnackBarUtils.showSnackBar(
          context,
          'User data not found',
          isError: true,
        );
        return;
      }

      List<Substation> substations = [];

      if (user.role == UserRole.substationUser) {
        final substationId = user.assignedLevels?['substationId'];
        if (substationId != null) {
          final substationDoc = await FirebaseFirestore.instance
              .collection('substations')
              .doc(substationId)
              .get();

          if (substationDoc.exists) {
            substations.add(Substation.fromFirestore(substationDoc));
          }
        }
      }

      setState(() {
        _accessibleSubstations = substations;
        if (substations.isNotEmpty && _selectedSubstationForLogsheet == null) {
          _selectedSubstationForLogsheet = substations.first;
        }
      });
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load substations: $e',
          isError: true,
        );
      }
    } finally {
      setState(() => _isLoadingSubstations = false);
    }
  }

  Future<void> _selectSingleDate() async {
    // Remove BuildContext parameter
    final theme = Theme.of(context); // Use context from build method
    final DateTime? picked = await showDatePicker(
      context: context, // Use context from build method
      initialDate: _singleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _singleDate) {
      setState(() {
        _singleDate = picked;
      });
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.electrical_services,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${widget.currentUser.email}!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Role: Substation User',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Text(
                'No substation assigned to your account.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAccessibleSubstations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Substation Operations',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: _selectSingleDate,
            icon: Icon(
              Icons.calendar_today,
              color: theme.colorScheme.onSurface,
            ),
            tooltip: 'Select Date',
          ),
        ],
        bottom: _accessibleSubstations.isNotEmpty
            ? TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: Icon(
                      Icons.access_time,
                      color: _currentTabIndex == 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    text: 'Operations',
                  ),
                  Tab(
                    icon: Icon(
                      Icons.electrical_services,
                      color: _currentTabIndex == 1
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    text: 'Energy',
                  ),
                  Tab(
                    icon: Icon(
                      Icons.warning,
                      color: _currentTabIndex == 2
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    text: 'Events',
                  ),
                ],
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
              )
            : null,
      ),
      drawer: widget.drawer,
      body: SafeArea(
        child: _isLoadingSubstations
            ? Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading substation data...',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : _accessibleSubstations.isEmpty
            ? _buildEmptyState(theme)
            : Column(
                children: [
                  // Date Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(_singleDate),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  // Tab Content
                  Expanded(
                    child: FadeTransition(
                      opacity: _animationController,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          SubstationUserOperationsTab(
                            substationId:
                                _selectedSubstationForLogsheet?.id ?? '',
                            substationName:
                                _selectedSubstationForLogsheet?.name ??
                                'Unknown',
                            currentUser: widget.currentUser,
                            selectedDate: _singleDate,
                          ),
                          SubstationUserEnergyTab(
                            substationId:
                                _selectedSubstationForLogsheet?.id ?? '',
                            substationName:
                                _selectedSubstationForLogsheet?.name ??
                                'Unknown',
                            currentUser: widget.currentUser,
                            selectedDate: _singleDate,
                          ),
                          SubstationUserTrippingTab(
                            substationId:
                                _selectedSubstationForLogsheet?.id ?? '',
                            substationName:
                                _selectedSubstationForLogsheet?.name ??
                                'Unknown',
                            currentUser: widget.currentUser,
                            selectedDate: _singleDate,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
