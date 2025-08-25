import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/app_state_data.dart';
import '../screens/common/notification_preferences_screen.dart';
import '../screens/common/user_profile_screen.dart';
import '../screens/power_pulse/dashboard_screen.dart';

class ModernAppDrawer extends StatelessWidget {
  final AppUser user;

  const ModernAppDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(); // This won't be used directly
  }

  // Static method to show the bottom modal sheet
  static void show(BuildContext context, AppUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BottomDrawerContent(user: user),
    );
  }
}

class _BottomDrawerContent extends StatefulWidget {
  final AppUser user;

  const _BottomDrawerContent({required this.user});

  @override
  State<_BottomDrawerContent> createState() => _BottomDrawerContentState();
}

class _BottomDrawerContentState extends State<_BottomDrawerContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: GestureDetector(
          onTap: () {}, // Prevent dismissing when tapping on the sheet
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  MediaQuery.of(context).size.height * _slideAnimation.value,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            isDarkMode ? 0.6 : 0.15,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(
                          context,
                          widget.user,
                          isDarkMode: isDarkMode,
                        ),
                        _buildContent(context, theme, isDarkMode),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // UPDATED: Enhanced user-based header
  Widget _buildHeader(
    BuildContext context,
    AppUser user, {
    bool isDarkMode = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          const SizedBox(height: 20),

          // User Profile Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // User Avatar with Role-based Color
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getRoleColor(user.role).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : user.email[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(user.role),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Name
                      Text(
                        user.name.isNotEmpty ? user.name : 'User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(user.role).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getRoleColor(user.role).withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _getRoleDisplayName(user.role),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getRoleColor(user.role),
                          ),
                        ),
                      ),

                      // Optional: Show user's current posting if available
                      if (user.currentPostingDisplay != 'Not assigned') ...[
                        const SizedBox(height: 6),
                        Text(
                          user.currentPostingDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : Colors.black.withOpacity(0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),

                // Optional: Status indicator
                if (!user.approved)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.pending,
                      color: Colors.orange,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, bool isDarkMode) {
    final navigationItems = _getNavigationItems(context);

    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation items in a vertical list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: navigationItems.length,
            itemBuilder: (context, index) {
              final item = navigationItems[index];
              return _buildNavigationTile(context, theme, isDarkMode, item);
            },
          ),

          const SizedBox(height: 20),

          // Separator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 1,
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),

          const SizedBox(height: 20),

          // Settings section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildSettingsTile(
                    context,
                    theme,
                    isDarkMode,
                    Icons.account_circle_outlined,
                    'Profile',
                    onTap: () => _navigateToProfile(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSettingsTile(
                    context,
                    theme,
                    isDarkMode,
                    Icons.dark_mode_rounded,
                    'Dark Mode',
                    isToggle: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSettingsTile(
                    context,
                    theme,
                    isDarkMode,
                    Icons.logout_rounded,
                    'Sign Out',
                    onTap: () => _showLogoutDialog(context),
                    isLogout: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context,
    ThemeData theme,
    bool isDarkMode,
    Map<String, dynamic> item,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item['onTap'],
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item['color'].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item['icon'], color: item['color'], size: 18),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['subtitle'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    ThemeData theme,
    bool isDarkMode,
    IconData icon,
    String title, {
    VoidCallback? onTap,
    bool isToggle = false,
    bool isLogout = false,
  }) {
    final appStateData = Provider.of<AppStateData>(context, listen: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isToggle ? () => appStateData.toggleTheme() : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isLogout
                      ? Colors.red.withOpacity(0.15)
                      : theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isLogout ? Colors.red : theme.colorScheme.primary,
                  size: 16,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isLogout
                      ? Colors.red
                      : (isDarkMode ? Colors.white : Colors.black),
                ),
                textAlign: TextAlign.center,
              ),

              if (isToggle) ...[
                const SizedBox(height: 4),
                Container(
                  width: 28,
                  height: 16,
                  decoration: BoxDecoration(
                    color: appStateData.themeMode == ThemeMode.dark
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: appStateData.themeMode == ThemeMode.dark
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getNavigationItems(BuildContext context) {
    switch (widget.user.role) {
      case UserRole.admin:
      case UserRole.superAdmin:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'System overview',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
        ];

      case UserRole.companyManager:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'Company overview',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
        ];

      case UserRole.stateManager:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'State overview',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
        ];

      case UserRole.zoneManager:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'Zone overview',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
        ];

      case UserRole.circleManager:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'Circle overview',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
        ];

      case UserRole.divisionManager:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'Division overview',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
        ];

      case UserRole.subdivisionManager:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'Subdivision overview',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
          {
            'icon': Icons.notifications_rounded,
            'title': 'Notification Preferences',
            'subtitle': 'Configure event alerts',
            'onTap': () => _navigateToNotificationPreferences(context),
            'color': Colors.amber,
          },
          {
            'icon': Icons.dashboard_rounded,
            'title': 'PowerPulse',
            'subtitle': 'Ideas in Power & Transmission',
            'onTap': () => _navigateToPowerPulseDashboardScreen(context),
            'color': Colors.blue,
          },
        ];

      case UserRole.substationUser:
      default:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'Substation data',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
        ];
    }
  }

  // Navigation methods
  void _navigateToProfile(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(currentUser: widget.user),
      ),
    );
  }

  void _navigateToPowerPulseDashboardScreen(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PowerPulseDashboardScreen(),
      ),
    );
  }

  void _navigateToNotificationPreferences(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            NotificationPreferencesScreen(currentUser: widget.user),
      ),
    );
  }
}

// Helper methods for role colors and display names
Color _getRoleColor(UserRole role) {
  switch (role) {
    case UserRole.admin:
    case UserRole.superAdmin:
      return Colors.red;
    case UserRole.companyManager:
      return Colors.purple;
    case UserRole.stateManager:
      return Colors.indigo;
    case UserRole.zoneManager:
      return Colors.cyan;
    case UserRole.circleManager:
      return Colors.green;
    case UserRole.divisionManager:
      return Colors.orange;
    case UserRole.subdivisionManager:
      return Colors.purple;
    case UserRole.substationUser:
      return Colors.teal;
    case UserRole.pending:
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

String _getRoleDisplayName(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Administrator';
    case UserRole.superAdmin:
      return 'Super Admin';
    case UserRole.companyManager:
      return 'Company Manager';
    case UserRole.stateManager:
      return 'State Manager';
    case UserRole.zoneManager:
      return 'Zone Manager';
    case UserRole.circleManager:
      return 'Circle Manager';
    case UserRole.divisionManager:
      return 'Division Manager';
    case UserRole.subdivisionManager:
      return 'Subdivision Manager';
    case UserRole.substationUser:
      return 'Substation User';
    case UserRole.pending:
      return 'Pending Approval';
    default:
      return 'User';
  }
}

void _showLogoutDialog(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode
                ? Colors.white.withOpacity(0.8)
                : Colors.black.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              Navigator.pop(context);

              try {
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut();
              } catch (e) {
                print('Error during sign out: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      );
    },
  );
}
