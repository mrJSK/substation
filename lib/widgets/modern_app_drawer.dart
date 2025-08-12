import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/app_state_data.dart';
import '../screens/admin/reading_template_management_screen.dart';
import '../screens/equipment_hierarchy_selection_screen.dart';
import '../screens/report_builder_wizard_screen.dart';
import '../screens/saved_sld_list_screen.dart';
import '../models/hierarchy_models.dart';
import '../screens/subdivision_dashboard_tabs/chart_configuration_screen.dart';
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart';
import '../controllers/sld_controller.dart';
import '../utils/snackbar_utils.dart';

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
                        _buildHeader(context, theme, isDarkMode),
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

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDarkMode) {
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

          // App info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.electrical_services,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Substation Manager',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(
                            widget.user.role,
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRoleDisplayName(widget.user.role),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getRoleColor(widget.user.role),
                          ),
                        ),
                      ),
                    ],
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isLogout
                      ? Colors.red.withOpacity(0.15)
                      : theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isLogout ? Colors.red : theme.colorScheme.primary,
                  size: 18,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
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
                  width: 32,
                  height: 18,
                  decoration: BoxDecoration(
                    color: appStateData.themeMode == ThemeMode.dark
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: appStateData.themeMode == ThemeMode.dark
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 14,
                      height: 14,
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
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'System overview',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
        ];

      case UserRole.subdivisionManager:
        return [
          {
            'icon': Icons.dashboard_rounded,
            'title': 'Dashboard',
            'subtitle': 'Subdivision view',
            'onTap': () => Navigator.pop(context),
            'color': Colors.blue,
          },
          {
            'icon': Icons.analytics_rounded, // Updated this icon
            'title': 'Custom Reports',
            'subtitle': 'Build & export reports',
            'onTap': () => _navigateToCustomReports(context),
            'color': Colors.purple,
          },
          {
            'icon': Icons.tune_rounded,
            'title': 'Charts',
            'subtitle': 'Configure charts',
            'onTap': () {
              Navigator.of(context).pop();
              if (widget.user.assignedLevels != null &&
                  widget.user.assignedLevels!.containsKey('subdivisionId')) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ReadingConfigurationScreen(
                      currentUser: widget.user,
                      subdivisionId:
                          widget.user.assignedLevels!['subdivisionId']!,
                    ),
                  ),
                );
              } else {
                SnackBarUtils.showSnackBar(
                  context,
                  'No subdivision assigned to this user.',
                  isError: true,
                );
              }
            },
            'color': Colors.teal,
          },
          {
            'icon': Icons.flash_on_rounded,
            'title': 'Energy SLD',
            'subtitle': 'Line diagrams',
            'onTap': () => _navigateToEnergySLD(context),
            'color': Colors.green,
          },
          {
            'icon': Icons.history_rounded,
            'title': 'Saved SLDs',
            'subtitle': 'Previous diagrams',
            'onTap': () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SavedSldListScreen(currentUser: widget.user),
                ),
              );
            },
            'color': Colors.orange,
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
          {
            'icon': Icons.analytics_rounded,
            'title': 'Custom Reports',
            'subtitle': 'Build & export reports',
            'onTap': () => _navigateToCustomReports(context),
            'color': Colors.purple,
          },
        ];
    }
  }

  // Add this new method for Custom Reports navigation
  void _navigateToCustomReports(BuildContext context) {
    Navigator.of(context).pop(); // Close the drawer

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReportBuilderWizardScreen(
          currentUser:
              widget.user, // This should work if widget.user is of type AppUser
        ),
      ),
    );
  }

  void _navigateToEnergySLD(BuildContext context) async {
    Navigator.of(context).pop();
    final selectedSubstation =
        await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    EquipmentHierarchySelectionScreen(currentUser: widget.user),
              ),
            )
            as Substation?;

    if (selectedSubstation != null) {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider<SldController>(
              create: (context) => SldController(
                substationId: selectedSubstation.id,
                transformationController: TransformationController(),
              ),
              child: EnergySldScreen(
                substationId: selectedSubstation.id,
                substationName: selectedSubstation.name,
                currentUser: widget.user,
              ),
            ),
          ),
        );
      }
    } else {
      if (context.mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'No substation selected for Energy SLD.',
          isError: true,
        );
      }
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.subdivisionManager:
        return Colors.purple;
      case UserRole.substationUser:
        return Colors.teal;
      case UserRole.divisionManager:
        return Colors.orange;
      case UserRole.circleManager:
        return Colors.green;
      case UserRole.zoneManager:
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.subdivisionManager:
        return 'Subdivision Manager';
      case UserRole.substationUser:
        return 'Substation User';
      case UserRole.divisionManager:
        return 'Division Manager';
      case UserRole.circleManager:
        return 'Circle Manager';
      case UserRole.zoneManager:
        return 'Zone Manager';
      default:
        return role.toString();
    }
  }

  void _showLogoutDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Use different context name
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
              onPressed: () =>
                  Navigator.pop(dialogContext), // Close only dialog
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
                // Close the logout dialog first
                Navigator.pop(dialogContext);

                // Close the drawer modal sheet
                Navigator.pop(context);

                // Then sign out
                try {
                  await FirebaseAuth.instance.signOut();
                  await GoogleSignIn().signOut();
                } catch (e) {
                  print('Error during sign out: $e');
                  // Optionally show error message
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
}
