// lib/screens/subdivision_dashboard_tabs/subdivision_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../models/app_state_data.dart';
import '../../widgets/modern_app_drawer.dart';
import 'reports_tab.dart';
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

  // Notification state (keep this)
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;

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
    print('🔍 DEBUG: SubdivisionDashboardScreen initState called');
    print('🔍 DEBUG: Current user: ${widget.currentUser.email}');
    final tabCount = widget.currentUser.role == UserRole.subdivisionManager
        ? _tabs.length
        : _tabs.length - 1; // Exclude Asset Management for non-managers
    _tabController = TabController(length: tabCount, vsync: this);

    // Load notification count
    _loadNotificationCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load unread notification count
  Future<void> _loadNotificationCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get unread notifications count for the current user
      final unreadQuery = await FirebaseFirestore.instance
          .collection('userNotifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      if (mounted) {
        setState(() {
          _unreadNotificationCount = unreadQuery.docs.length;
        });
      }
    } catch (e) {
      print('Error loading notification count: $e');
    }
  }

  // Show notifications bottom sheet
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationBottomSheet(
        currentUser: widget.currentUser,
        onNotificationRead: () {
          // Refresh notification count when a notification is read
          _loadNotificationCount();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 DEBUG: SubdivisionDashboardScreen build called');
    final theme = Theme.of(context);
    final appState = Provider.of<AppStateData>(context);
    final accessibleSubstations = appState.accessibleSubstations;

    if (accessibleSubstations.isEmpty) {
      return _buildNoSubstationState(theme);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(theme), // Simplified AppBar
      body: Column(
        children: [
          _buildTabBar(theme),
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

  // Simplified AppBar without substation selector and date picker
  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 60, // Reduced height
      title: Text(
        'Subdivision Dashboard',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
        onPressed: () {
          print('🔍 DEBUG: Menu button pressed in SubdivisionDashboard');
          ModernAppDrawer.show(context, widget.currentUser);
        },
      ),
      actions: [_buildNotificationIcon(theme), const SizedBox(width: 8)],
    );
  }

  // Build notification bell icon with badge
  Widget _buildNotificationIcon(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          IconButton(
            onPressed: _showNotifications,
            icon: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.notifications_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            tooltip: 'Notifications',
          ),
          // Badge for unread count
          if (_unreadNotificationCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  _unreadNotificationCount > 99
                      ? '99+'
                      : _unreadNotificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
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
        actions: [_buildNotificationIcon(theme), const SizedBox(width: 8)],
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

  // Updated tab views to pass accessible substations
  List<Widget> _buildTabViews(List<Substation> accessibleSubstations) {
    final List<Widget> views = [
      OperationsTab(
        currentUser: widget.currentUser,
        accessibleSubstations: accessibleSubstations, // Pass substations
      ),
      EnergyTab(
        currentUser: widget.currentUser,
        initialSelectedSubstationId: null, // Remove fixed selection
        substationId: '', // Will be set in tab
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
      ),
      TrippingTab(
        currentUser: widget.currentUser,
        substationId: '', // Will be set in tab
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
      ),
      GenerateCustomReportScreen(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
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

// Notification Bottom Sheet Widget
class _NotificationBottomSheet extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onNotificationRead;

  const _NotificationBottomSheet({
    required this.currentUser,
    required this.onNotificationRead,
  });

  @override
  State<_NotificationBottomSheet> createState() =>
      _NotificationBottomSheetState();
}

class _NotificationBottomSheetState extends State<_NotificationBottomSheet> {
  bool _isLoading = true;
  List<NotificationData> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load recent notifications (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final notificationsQuery = await FirebaseFirestore.instance
          .collection('userNotifications')
          .where('userId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final notifications = notificationsQuery.docs.map((doc) {
        final data = doc.data();
        return NotificationData(
          id: doc.id,
          title: data['title'] ?? 'Notification',
          body: data['body'] ?? '',
          eventType: data['eventType'] ?? 'general',
          substationName: data['substationName'] ?? '',
          bayName: data['bayName'] ?? '',
          isRead: data['read'] ?? false,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          eventId: data['eventId'],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('userNotifications')
          .doc(notificationId)
          .update({'read': true});

      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
        }
      });

      // Notify parent to refresh count
      widget.onNotificationRead();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Mark all unread notifications as read
      final batch = FirebaseFirestore.instance.batch();
      final unreadNotifications = _notifications.where((n) => !n.isRead);

      for (final notification in unreadNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection('userNotifications')
            .doc(notification.id);
        batch.update(docRef, {'read': true});
      }

      await batch.commit();

      // Update local state
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
      });

      // Notify parent to refresh count
      widget.onNotificationRead();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (_notifications.any((n) => !n.isRead))
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: Text(
                      'Mark all read',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'re all caught up!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _buildNotificationItem(notification, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationData notification,
    ThemeData theme,
  ) {
    final isUnread = !notification.isRead;
    final eventColor = notification.eventType == 'tripping'
        ? Colors.red
        : notification.eventType == 'shutdown'
        ? Colors.orange
        : Colors.blue;

    return InkWell(
      onTap: isUnread ? () => _markAsRead(notification.id) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? theme.colorScheme.primary.withOpacity(0.05) : null,
          borderRadius: BorderRadius.circular(8),
          border: isUnread
              ? Border.all(color: theme.colorScheme.primary.withOpacity(0.2))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: eventColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                notification.eventType == 'tripping'
                    ? Icons.flash_on
                    : notification.eventType == 'shutdown'
                    ? Icons.power_off
                    : Icons.info_outline,
                color: eventColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatNotificationTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      if (notification.substationName.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notification.substationName,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }
}

// Notification Data Model
class NotificationData {
  final String id;
  final String title;
  final String body;
  final String eventType;
  final String substationName;
  final String bayName;
  final bool isRead;
  final DateTime createdAt;
  final String? eventId;

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.eventType,
    required this.substationName,
    required this.bayName,
    required this.isRead,
    required this.createdAt,
    this.eventId,
  });

  NotificationData copyWith({
    String? id,
    String? title,
    String? body,
    String? eventType,
    String? substationName,
    String? bayName,
    bool? isRead,
    DateTime? createdAt,
    String? eventId,
  }) {
    return NotificationData(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      eventType: eventType ?? this.eventType,
      substationName: substationName ?? this.substationName,
      bayName: bayName ?? this.bayName,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      eventId: eventId ?? this.eventId,
    );
  }
}

class TabData {
  final String label;
  final IconData icon;
  final Color color;

  TabData(this.label, this.icon, this.color);
}
