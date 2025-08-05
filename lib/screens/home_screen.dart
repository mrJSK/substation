import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart';
import '../screens/auth_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/equipment_hierarchy_selection_screen.dart';
import 'subdivision_dashboard_tabs/energy_sld_screen.dart';
import '../screens/saved_sld_list_screen.dart';
import 'substation_dashboard/substation_user_dashboard_screen.dart';
import 'subdivision_dashboard_tabs/subdivision_dashboard_screen.dart';
import '../screens/admin/reading_template_management_screen.dart';
import 'subdivision_dashboard_tabs/chart_configuration_screen.dart';
import '../controllers/sld_controller.dart';
import '../utils/snackbar_utils.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final appStateData = Provider.of<AppStateData>(context);
    final theme = Theme.of(context);

    if (!appStateData.isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    final AppUser? currentUser = appStateData.currentUser;

    if (currentUser == null) {
      return const AuthScreen();
    } else {
      if (currentUser.approved) {
        switch (currentUser.role) {
          case UserRole.admin:
            return AdminHomeScreen(appUser: currentUser);
          case UserRole.substationUser:
            return SubstationUserHomeScreen(appUser: currentUser);
          case UserRole.subdivisionManager:
            return SubdivisionManagerHomeScreen(appUser: currentUser);
          default:
            WidgetsBinding.instance.addPostFrameCallback((_) {
              SnackBarUtils.showSnackBar(
                context,
                'Your user role is not recognized. Please log in again or contact support.',
                isError: true,
              );
              FirebaseAuth.instance.signOut();
              GoogleSignIn().signOut();
            });
            return const AuthScreen();
        }
      } else {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your account is pending approval by an admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while an administrator reviews your registration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }
}

abstract class BaseHomeScreen extends StatefulWidget {
  final AppUser appUser;
  final Widget? drawer;

  const BaseHomeScreen({super.key, required this.appUser, this.drawer});

  @override
  BaseHomeScreenState createState();
}

abstract class BaseHomeScreenState<T extends BaseHomeScreen> extends State<T> {
  @override
  Widget build(BuildContext context) {
    return buildBody(context);
  }

  Widget buildBody(BuildContext context);
}

class AdminHomeScreen extends BaseHomeScreen {
  static const String routeName = '/admin_home';

  const AdminHomeScreen({super.key, required super.appUser});

  @override
  BaseHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends BaseHomeScreenState<AdminHomeScreen> {
  @override
  Widget buildBody(BuildContext context) {
    return AdminDashboardScreen(
      adminUser: widget.appUser,
      drawer: _buildAdminDrawer(context),
    );
  }

  Widget _buildAdminDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: const Color(0xFFFAFAFA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context, 'Admin'),
          _buildDrawerItem(
            icon: Icons.rule,
            title: 'Reading Templates',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ReadingTemplateManagementScreen(),
                ),
              );
            },
            theme: theme,
          ),
          _buildDrawerItem(
            icon: Icons.flash_on,
            title: 'Energy SLD',
            onTap: () async {
              Navigator.of(context).pop();
              final selectedSubstation =
                  await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              EquipmentHierarchySelectionScreen(
                                currentUser: widget.appUser,
                              ),
                        ),
                      )
                      as Substation?;
              if (selectedSubstation != null) {
                if (!mounted) return;
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
                        currentUser: widget.appUser,
                      ),
                    ),
                  ),
                );
              } else {
                if (!mounted) return;
                SnackBarUtils.showSnackBar(
                  context,
                  'No substation selected for Energy SLD.',
                  isError: true,
                );
              }
            },
            theme: theme,
          ),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'View Saved SLDs',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SavedSldListScreen(currentUser: widget.appUser),
                ),
              );
            },
            theme: theme,
          ),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          _buildThemeToggle(context),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, String role) {
    final theme = Theme.of(context);
    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Substation Manager Pro',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.appUser.email,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Role: $role',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class SubstationUserHomeScreen extends BaseHomeScreen {
  static const String routeName = '/substation_user_home';

  const SubstationUserHomeScreen({super.key, required super.appUser});

  @override
  BaseHomeScreenState createState() => _SubstationUserHomeScreenState();
}

class _SubstationUserHomeScreenState
    extends BaseHomeScreenState<SubstationUserHomeScreen> {
  @override
  Widget buildBody(BuildContext context) {
    return SubstationUserDashboardScreen(
      currentUser: widget.appUser,
      drawer: _buildSubstationUserDrawer(context),
    );
  }

  Widget _buildSubstationUserDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: const Color(0xFFFAFAFA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context, 'Substation User'),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          _buildThemeToggle(context),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, String role) {
    final theme = Theme.of(context);
    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Substation Manager Pro',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.appUser.email,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Role: $role',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class SubdivisionManagerHomeScreen extends BaseHomeScreen {
  static const String routeName = '/subdivision_manager_home';

  const SubdivisionManagerHomeScreen({super.key, required super.appUser});

  @override
  BaseHomeScreenState createState() => _SubdivisionManagerHomeScreenState();
}

class _SubdivisionManagerHomeScreenState
    extends BaseHomeScreenState<SubdivisionManagerHomeScreen> {
  @override
  Widget buildBody(BuildContext context) {
    return SubdivisionDashboardScreen(
      currentUser: widget.appUser,
      drawer: _buildSubdivisionManagerDrawer(context),
    );
  }

  Widget _buildSubdivisionManagerDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: const Color(0xFFFAFAFA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context, 'Subdivision Manager'),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Subdivision Dashboard',
            onTap: () {
              Navigator.of(context).pop();
            },
            theme: theme,
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Configure Charts',
            onTap: () {
              Navigator.of(context).pop();
              if (widget.appUser.assignedLevels != null &&
                  widget.appUser.assignedLevels!.containsKey('subdivisionId')) {
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ReadingConfigurationScreen(
                      currentUser: widget.appUser,
                      subdivisionId:
                          widget.appUser.assignedLevels!['subdivisionId']!,
                    ),
                  ),
                );
              } else {
                if (!mounted) return;
                SnackBarUtils.showSnackBar(
                  context,
                  'No subdivision assigned to this user.',
                  isError: true,
                );
              }
            },
            theme: theme,
          ),
          _buildDrawerItem(
            icon: Icons.flash_on,
            title: 'Energy SLD',
            onTap: () async {
              Navigator.of(context).pop();
              final selectedSubstation =
                  await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              EquipmentHierarchySelectionScreen(
                                currentUser: widget.appUser,
                              ),
                        ),
                      )
                      as Substation?;
              if (selectedSubstation != null) {
                if (!mounted) return;
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
                        currentUser: widget.appUser,
                      ),
                    ),
                  ),
                );
              } else {
                if (!mounted) return;
                SnackBarUtils.showSnackBar(
                  context,
                  'No substation selected for Energy SLD.',
                  isError: true,
                );
              }
            },
            theme: theme,
          ),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'View Saved SLDs',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SavedSldListScreen(currentUser: widget.appUser),
                ),
              );
            },
            theme: theme,
          ),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          _buildThemeToggle(context),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, String role) {
    final theme = Theme.of(context);
    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Substation Manager Pro',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.appUser.email,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Role: $role',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildDrawerItem({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  required ThemeData theme,
}) {
  return ListTile(
    leading: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 16, color: theme.colorScheme.primary),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    tileColor: Colors.white,
    selectedTileColor: theme.colorScheme.primary.withOpacity(0.05),
  );
}

Widget _buildThemeToggle(BuildContext context) {
  final theme = Theme.of(context);
  final appStateData = Provider.of<AppStateData>(context, listen: false);
  return ListTile(
    leading: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        appStateData.themeMode == ThemeMode.light
            ? Icons.dark_mode
            : Icons.light_mode,
        size: 16,
        color: theme.colorScheme.primary,
      ),
    ),
    title: const Text(
      'Dark Mode',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    trailing: Switch(
      value: appStateData.themeMode == ThemeMode.dark,
      onChanged: (value) {
        appStateData.toggleTheme();
      },
      activeColor: theme.colorScheme.primary,
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.shade200,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    tileColor: Colors.white,
    selectedTileColor: theme.colorScheme.primary.withOpacity(0.05),
  );
}

Widget _buildLogoutTile(BuildContext context) {
  final theme = Theme.of(context);
  return ListTile(
    leading: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.logout, size: 16, color: theme.colorScheme.error),
    ),
    title: const Text(
      'Logout',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.red,
      ),
    ),
    onTap: () async {
      Navigator.of(context).pop();
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    },
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    tileColor: Colors.white,
    selectedTileColor: theme.colorScheme.error.withOpacity(0.05),
  );
}
