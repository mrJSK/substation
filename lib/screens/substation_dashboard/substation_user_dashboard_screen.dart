import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/app_state_data.dart';
import '../../models/hierarchy_models.dart';
import '../../models/user_model.dart';
import '../../services/comprehensive_cache_service.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/modern_app_drawer.dart';
import 'substation_user_operations_tab.dart';
import 'substation_user_energy_tab.dart';
import 'substation_user_tripping_tab.dart';

class SubstationUserDashboardScreen extends StatefulWidget {
  final AppUser currentUser;

  const SubstationUserDashboardScreen({super.key, required this.currentUser});

  @override
  State<SubstationUserDashboardScreen> createState() =>
      _SubstationUserDashboardScreenState();
}

class _SubstationUserDashboardScreenState
    extends State<SubstationUserDashboardScreen>
    with TickerProviderStateMixin {
  final ComprehensiveCacheService _cache = ComprehensiveCacheService();

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
    _loadAccessibleSubstationsAndInitializeCache();
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

  Future<void> _loadAccessibleSubstationsAndInitializeCache() async {
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
          // ✅ INITIALIZE COMPREHENSIVE CACHE
          try {
            await _cache.initializeForUser(user);
            print('✅ Comprehensive cache initialized successfully');

            // Get substation from cache instead of Firebase
            final substationData = _cache.substationData;
            if (substationData != null) {
              substations.add(substationData.substation);
            }
          } catch (cacheError) {
            print('❌ Cache initialization failed: $cacheError');
            // Fallback to Firebase query
            final substationDoc = await FirebaseFirestore.instance
                .collection('substations')
                .doc(substationId)
                .get();

            if (substationDoc.exists) {
              substations.add(Substation.fromFirestore(substationDoc));
            }
          }
        }
      }

      setState(() {
        _accessibleSubstations = substations;
        if (substations.isNotEmpty && _selectedSubstationForLogsheet == null) {
          _selectedSubstationForLogsheet = substations.first;
        }
      });

      print(
        '✅ Dashboard initialized with ${substations.length} accessible substations',
      );
    } catch (e) {
      print('❌ Error loading substations: $e');
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _singleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
            ),
            dialogBackgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
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

  Future<void> _refreshData() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshing data...'),
          duration: Duration(seconds: 1),
        ),
      );

      // ✅ FORCE CACHE REFRESH
      await _cache.forceRefresh();

      // Trigger rebuild of all tabs
      setState(() {});

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh data: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildEmptyState(ThemeData theme, bool isDarkMode) {
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
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
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Role: Substation User',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No substation assigned to your account.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAccessibleSubstationsAndInitializeCache,
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
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Substation Operations',
              style: TextStyle(
                color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_cache.isInitialized) ...[
              const SizedBox(width: 12),
              // Cache status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_bolt, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'CACHED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
          onPressed: () {
            // Show the bottom modal drawer
            ModernAppDrawer.show(context, widget.currentUser);
          },
        ),
        actions: [
          IconButton(
            onPressed: _selectSingleDate,
            icon: Icon(
              Icons.calendar_today,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
            tooltip: 'Select Date',
          ),
          IconButton(
            onPressed: _refreshData,
            icon: Icon(
              Icons.refresh,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
            tooltip: 'Refresh Data',
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
                          : (isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : theme.colorScheme.onSurfaceVariant),
                    ),
                    text: 'Operations',
                  ),
                  Tab(
                    icon: Icon(
                      Icons.electrical_services,
                      color: _currentTabIndex == 1
                          ? theme.colorScheme.primary
                          : (isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : theme.colorScheme.onSurfaceVariant),
                    ),
                    text: 'Energy',
                  ),
                  Tab(
                    icon: Icon(
                      Icons.warning,
                      color: _currentTabIndex == 2
                          ? theme.colorScheme.primary
                          : (isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : theme.colorScheme.onSurfaceVariant),
                    ),
                    text: 'Events',
                  ),
                ],
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
              )
            : null,
      ),
      body: SafeArea(
        child: _isLoadingSubstations
            ? Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
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
                          _cache.isInitialized
                              ? 'Loading from cache...'
                              : 'Initializing cache and loading data...',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                        if (!_cache.isInitialized) ...[
                          const SizedBox(height: 8),
                          Text(
                            'This may take a moment on first launch',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            : _accessibleSubstations.isEmpty
            ? _buildEmptyState(theme, isDarkMode)
            : Column(
                children: [
                  // Date Display with performance indicator
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(_singleDate),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (_cache.isInitialized) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flash_on,
                                  size: 10,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'INSTANT',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
