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

  // 🔧 FIX: Add cache health tracking
  bool _cacheHealthy = false;
  String? _cacheError;

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

  // 🔧 FIX: Enhanced cache initialization with better error handling
  Future<void> _loadAccessibleSubstationsAndInitializeCache() async {
    setState(() {
      _isLoadingSubstations = true;
      _cacheHealthy = false;
      _cacheError = null;
    });

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
        if (substationId == null) {
          setState(() {
            _cacheError = 'No substation assigned to your account';
            _accessibleSubstations = [];
          });
          return;
        }

        try {
          // 🔧 FIX: Initialize cache with timeout and retry logic
          print('🔄 Initializing comprehensive cache...');
          await _cache.initializeForUser(user);

          // 🔧 FIX: Validate cache after initialization
          if (!_cache.validateCache()) {
            throw Exception('Cache validation failed after initialization');
          }

          print('✅ Comprehensive cache initialized and validated successfully');
          _cacheHealthy = true;

          // Get substation from cache
          final substationData = _cache.substationData;
          if (substationData != null) {
            substations.add(substationData.substation);
            print(
              '✅ Substation data loaded from cache: ${substationData.substation.name}',
            );
          } else {
            throw Exception('Substation data not found in cache');
          }
        } catch (cacheError) {
          print('❌ Cache initialization failed: $cacheError');
          _cacheError = cacheError.toString();
          _cacheHealthy = false;

          // 🔧 FIX: Fallback to Firebase with better error handling
          try {
            print('🔄 Falling back to Firebase direct query...');
            final substationDoc = await FirebaseFirestore.instance
                .collection('substations')
                .doc(substationId)
                .get();

            if (substationDoc.exists) {
              substations.add(Substation.fromFirestore(substationDoc));
              print('✅ Substation loaded from Firebase fallback');
            } else {
              throw Exception(
                'Substation not found in Firebase: $substationId',
              );
            }
          } catch (firebaseError) {
            print('❌ Firebase fallback also failed: $firebaseError');
            setState(() {
              _cacheError = 'Failed to load substation data: $firebaseError';
            });
            return;
          }
        }
      } else {
        // 🔧 FIX: Handle non-substation users gracefully
        setState(() {
          _cacheError = 'Access restricted to substation users only';
        });
        return;
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
      print('❌ Critical error loading substations: $e');
      setState(() {
        _cacheError = e.toString();
        _cacheHealthy = false;
      });

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load dashboard: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSubstations = false);
      }
    }
  }

  // 🔧 FIX: Enhanced date selection with validation
  Future<void> _selectSingleDate() async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _singleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ), // Allow tomorrow for shift planning
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

      // 🔧 FIX: Optionally refresh data when date changes significantly
      final daysDiff = _singleDate.difference(picked).inDays.abs();
      if (daysDiff > 1 && _cacheHealthy) {
        _refreshData();
      }
    }
  }

  // 🔧 FIX: Enhanced refresh with error recovery
  Future<void> _refreshData() async {
    if (!_cacheHealthy) {
      // If cache is unhealthy, try to reinitialize
      return _loadAccessibleSubstationsAndInitializeCache();
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Refreshing data...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 🔧 FIX: Force cache refresh with validation
      await _cache.forceRefresh();

      // Validate cache after refresh
      if (!_cache.validateCache()) {
        throw Exception('Cache became invalid after refresh');
      }

      setState(() {
        _cacheHealthy = true;
        _cacheError = null;
      });

      print('✅ Data refreshed successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Data refreshed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error refreshing data: $e');
      setState(() {
        _cacheHealthy = false;
        _cacheError = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to refresh: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _refreshData(),
            ),
          ),
        );
      }
    }
  }

  // 🔧 FIX: Enhanced empty state with better messaging
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
                _cacheError != null
                    ? Icons.error_outline
                    : Icons.electrical_services,
                size: 80,
                color: _cacheError != null
                    ? Colors.red
                    : theme.colorScheme.primary,
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
                'Role: ${widget.currentUser.role.name.split('.').last.replaceAll('_', ' ').toUpperCase()}',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // 🔧 FIX: Display specific error message
              if (_cacheError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _cacheError!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  'No substation data available.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  if (_cacheError != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        _cache.clearCache();
                        _loadAccessibleSubstationsAndInitializeCache();
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear Cache'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔧 FIX: Enhanced cache status indicator
  Widget _buildCacheStatusIndicator() {
    if (!_cache.isInitialized) return const SizedBox.shrink();

    final cacheStats = _cache.getCacheStats();
    final cacheAge = cacheStats['cacheAge'] ?? 0;

    Color statusColor = Colors.green;
    IconData statusIcon = Icons.offline_bolt;
    String statusText = 'CACHED';

    if (!_cacheHealthy) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'ERROR';
    } else if (cacheAge > 60) {
      // More than 1 hour old
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
      statusText = 'STALE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 10, color: statusColor),
          const SizedBox(width: 2),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
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
            const SizedBox(width: 12),
            // 🔧 FIX: Add cache status indicator
            // _buildCacheStatusIndicator(),
          ],
        ),
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
          onPressed: () {
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
            tooltip:
                'Select Date: ${DateFormat('dd/MM/yyyy').format(_singleDate)}',
          ),
          IconButton(
            onPressed: _cacheHealthy
                ? _refreshData
                : _loadAccessibleSubstationsAndInitializeCache,
            icon: Icon(
              _cacheHealthy ? Icons.refresh : Icons.error,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
            tooltip: _cacheHealthy ? 'Refresh Data' : 'Fix Connection',
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
                      Icons.bolt,
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
                    text: 'Trip/SD',
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
                          strokeWidth: 3,
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
                        // 🔧 FIX: Add progress indicator for cache operations
                        if (_cache.isInitialized) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            backgroundColor: theme.colorScheme.primary
                                .withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
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
                  // 🔧 FIX: Enhanced date display with better formatting
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(_singleDate),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        // 🔧 FIX: Add date status indicator
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _isToday()
                                ? Colors.green.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isToday()
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _isToday() ? 'TODAY' : 'HISTORICAL',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _isToday() ? Colors.green : Colors.blue,
                            ),
                          ),
                        ),
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

  // 🔧 FIX: Helper method for date checks
  bool _isToday() {
    final now = DateTime.now();
    return DateUtils.isSameDay(_singleDate, now);
  }
}
