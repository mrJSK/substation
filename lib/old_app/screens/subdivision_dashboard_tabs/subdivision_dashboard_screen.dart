// lib/screens/subdivision_dashboard_tabs/subdivision_dashboard_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../models/app_state_data.dart';
import '../../models/tripping_shutdown_model.dart';
import '../../widgets/modern_app_drawer.dart';
import 'overview.dart';
import 'reports_tab.dart';
import 'operations_tab.dart';
import 'energy_tab.dart';
import 'subdivision_asset_management_screen.dart';
import 'tripping_details_screen.dart';
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
  late List<TabData> _tabs;

  @override
  void initState() {
    super.initState();
    print('🔍 DEBUG: SubdivisionDashboardScreen initState called');
    print('🔍 DEBUG: Current user: ${widget.currentUser.email}');

    // Initialize tabs with Overview first
    _tabs = [
      TabData('Overview', Icons.show_chart, Colors.teal),
      TabData('Operations', Icons.settings, Colors.blue),
      TabData('Energy', Icons.electrical_services, Colors.green),
      TabData('Tripping', Icons.warning, Colors.orange),
      TabData('Asset Management', Icons.business, Colors.indigo),
    ];

    // Remove Asset Management tab for non-subdivision managers
    if (widget.currentUser.role != UserRole.subdivisionManager) {
      _tabs.removeWhere((tab) => tab.label == 'Asset Management');
    }

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: 0,
    );

    // Set up FCM notification handling for direct navigation to details screen
    _setupFCMNotificationHandler();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Set up FCM notification handling with direct navigation to details screen
  void _setupFCMNotificationHandler() {
    // Handle notification taps when app is terminated and opened via notification
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print(
          '🔍 App opened from terminated state via notification: ${message.messageId}',
        );
        _handleNotificationTap(message);
      }
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
        '🔍 App opened from background via notification: ${message.messageId}',
      );
      _handleNotificationTap(message);
    });

    // Handle foreground notifications (show simple banner)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔍 Received foreground notification: ${message.messageId}');
      if (mounted) {
        _showForegroundNotificationBanner(message);
      }
    });

    print('🔍 FCM notification handlers set up successfully');
  }

  /// Handle notification tap - navigate directly to details screen
  void _handleNotificationTap(RemoteMessage message) {
    final eventType = message.data['eventType']?.toLowerCase();
    final eventId = message.data['eventId'];
    final substationName = message.data['substationName'] ?? '';
    final bayName = message.data['bayName'] ?? '';

    print(
      '🔍 Handling notification tap - EventType: $eventType, EventID: $eventId',
    );

    // Navigate directly to details screen for tripping and shutdown events
    if ((eventType == 'tripping' || eventType == 'shutdown') &&
        eventId != null) {
      _navigateToEventDetails(eventId, substationName);
    } else {
      // Fallback: Navigate to tripping tab if eventId is missing
      final trippingTabIndex = _tabs.indexWhere(
        (tab) => tab.label == 'Tripping',
      );
      if (trippingTabIndex != -1) {
        _tabController.animateTo(trippingTabIndex);
      }
      print('🔍 Missing eventId or unknown event type: $eventType');
    }
  }

  /// Navigate directly to the event details screen
  Future<void> _navigateToEventDetails(
    String eventId,
    String substationName,
  ) async {
    try {
      print('🔍 Fetching event details for eventId: $eventId');

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      // Fetch the event details from Firestore
      final eventDoc = await FirebaseFirestore.instance
          .collection('trippingShutdownEntries')
          .doc(eventId)
          .get();

      // Hide loading indicator
      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
      }

      if (eventDoc.exists && mounted) {
        final eventData = eventDoc.data()!;
        final entry = TrippingShutdownEntry.fromFirestore(eventDoc);

        print(
          '🔍 Successfully fetched event: ${entry.eventType} at ${entry.bayName}',
        );

        // Navigate to details screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrippingDetailsScreen(
              entry: entry,
              substationName: substationName.isNotEmpty
                  ? substationName
                  : (eventData['substationName'] ?? 'Unknown Substation'),
            ),
          ),
        );
      } else {
        if (mounted) {
          // Event not found - show error and fallback to tripping tab
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Event details not found. Showing tripping events.',
              ),
              backgroundColor: Colors.orange,
            ),
          );

          final trippingTabIndex = _tabs.indexWhere(
            (tab) => tab.label == 'Tripping',
          );
          if (trippingTabIndex != -1) {
            _tabController.animateTo(trippingTabIndex);
          }
        }
        print('🔍 Event not found for eventId: $eventId');
      }
    } catch (e) {
      print('🔍 Error fetching event details: $e');

      // Hide loading indicator if still showing
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // Show error and fallback to tripping tab
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading event details. Showing tripping events.',
            ),
            backgroundColor: Colors.red,
          ),
        );

        final trippingTabIndex = _tabs.indexWhere(
          (tab) => tab.label == 'Tripping',
        );
        if (trippingTabIndex != -1) {
          _tabController.animateTo(trippingTabIndex);
        }
      }
    }
  }

  /// Show simple banner for foreground notifications
  void _showForegroundNotificationBanner(RemoteMessage message) {
    final eventType = message.data['eventType']?.toLowerCase();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.notification?.title ?? 'New Event',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.notification?.body ?? '',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: eventType == 'tripping' ? Colors.red : Colors.orange,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View Details',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _handleNotificationTap(message);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 DEBUG: SubdivisionDashboardScreen build called');
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final appState = Provider.of<AppStateData>(context);
    final accessibleSubstations = appState.accessibleSubstations;

    if (accessibleSubstations.isEmpty) {
      return _buildNoSubstationState(theme, isDarkMode);
    }

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF8F9FA),
      appBar: _buildAppBar(theme, isDarkMode),
      body: Column(
        children: [
          _buildTabBar(theme, isDarkMode),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _buildTabViews(accessibleSubstations),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      elevation: 0,
      toolbarHeight: 60,
      title: Text(
        'Subdivision Dashboard',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
        ),
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
    );
  }

  Widget _buildTabBar(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: _tabs.map((tab) => _buildCustomTab(tab, isDarkMode)).toList(),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.primary.withOpacity(0.1),
        ),
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: isDarkMode
            ? Colors.white.withOpacity(0.6)
            : Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        padding: const EdgeInsets.all(8),
        tabAlignment: TabAlignment.start,
      ),
    );
  }

  Widget _buildCustomTab(TabData tabData, bool isDarkMode) {
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

  Widget _buildNoSubstationState(ThemeData theme, bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        title: Text(
          'Subdivision Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
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
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.4)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Substations Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading substations or no accessible substations found. Please contact your administrator.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabViews(List<Substation> accessibleSubstations) {
    List<Widget> views = [
      OverviewScreen(
        currentUser: widget.currentUser,
        accessibleSubstations: accessibleSubstations,
      ),
      OperationsTab(
        currentUser: widget.currentUser,
        accessibleSubstations: accessibleSubstations,
      ),
      EnergyTab(
        currentUser: widget.currentUser,
        accessibleSubstations: accessibleSubstations,
      ),
      TrippingTab(
        currentUser: widget.currentUser,
        accessibleSubstations: accessibleSubstations,
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
}

class TabData {
  final String label;
  final IconData icon;
  final Color color;

  TabData(this.label, this.icon, this.color);
}
