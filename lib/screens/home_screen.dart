// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart'; // Import the updated AppStateData
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

// NEW: HomeRouter - This widget will handle routing based on authentication and user role
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to AppStateData for current user and initialization status
    final appStateData = Provider.of<AppStateData>(context);

    // Show a loading indicator if AppStateData is not yet fully initialized
    if (!appStateData.isInitialized) {
      // This state should ideally be handled by the FutureBuilder in main.dart
      // but as a fallback, if we somehow reach here before full init, show a simple loading.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final AppUser? currentUser = appStateData.currentUser;

    if (currentUser == null) {
      // No user is authenticated, navigate to AuthScreen
      return const AuthScreen();
    } else {
      // User is authenticated, check approval status and role
      if (currentUser.approved) {
        switch (currentUser.role) {
          case UserRole.admin:
            return AdminHomeScreen(appUser: currentUser);
          case UserRole.substationUser:
            return SubstationUserHomeScreen(appUser: currentUser);
          case UserRole.subdivisionManager:
            return SubdivisionManagerHomeScreen(appUser: currentUser);
          default:
            // Handle unrecognized roles or default to AuthScreen with a message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              SnackBarUtils.showSnackBar(
                context,
                'Your user role is not recognized. Please log in again or contact support.',
                isError: true,
              );
              // Force sign out if role is unrecognized
              FirebaseAuth.instance.signOut();
              GoogleSignIn().signOut();
            });
            return const AuthScreen();
        }
      } else {
        // User is not approved, show pending approval screen
        return const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 80, color: Colors.blue),
                  SizedBox(height: 20),
                  Text(
                    'Your account is pending approval by an admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Please wait while an administrator reviews your registration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
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

// Base Home Screen class for shared functionality
abstract class BaseHomeScreen extends StatefulWidget {
  final AppUser appUser;
  final Widget? drawer; // NEW: Add a drawer property

  const BaseHomeScreen({
    super.key,
    required this.appUser,
    this.drawer,
  }); // NEW: Add drawer to constructor

  @override
  BaseHomeScreenState createState();
}

abstract class BaseHomeScreenState<T extends BaseHomeScreen> extends State<T> {
  // buildDrawer is REMOVED from here. Each dashboard will provide its drawer to BaseHomeScreen.

  @override
  Widget build(BuildContext context) {
    // AppStateData is now handled by MyApp and HomeRouter for theme
    // We still need it here for the theme toggle in the drawer
    final appStateData = Provider.of<AppStateData>(
      context,
    ); // Keep for theme toggle in common drawer widgets

    // The Scaffold is now built WITHIN the AdminDashboardScreen, SubstationUserDashboardScreen, etc.
    // BaseHomeScreenState's build method will simply return the dashboard screen.
    return buildBody(context); // buildBody will now return a Scaffold
  }

  // This method will now return a Scaffold (which contains its own AppBar and body)
  Widget buildBody(BuildContext context);
}

// Admin Home Screen (remains largely the same)
class AdminHomeScreen extends BaseHomeScreen {
  static const String routeName = '/admin_home';

  const AdminHomeScreen({super.key, required super.appUser});

  @override
  BaseHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends BaseHomeScreenState<AdminHomeScreen> {
  @override
  Widget buildBody(BuildContext context) {
    // AdminDashboardScreen will now contain its own Scaffold and AppBar
    return AdminDashboardScreen(
      adminUser: widget.appUser,
      // Pass the common drawer to the dashboard screen
      drawer: _buildAdminDrawer(context),
    );
  }

  // Admin specific drawer
  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context, 'Admin'),
          ListTile(
            leading: const Icon(Icons.rule),
            title: const Text('Reading Templates'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ReadingTemplateManagementScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.flash_on),
            title: const Text('Energy SLD'),
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
                if (!mounted) return; // Add mounted check
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
                if (!mounted) return; // Add mounted check
                SnackBarUtils.showSnackBar(
                  context,
                  'No substation selected for Energy SLD.',
                  isError: true,
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View Saved SLDs'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SavedSldListScreen(currentUser: widget.appUser),
                ),
              );
            },
          ),
          const Divider(),
          _buildThemeToggle(context),
          const Divider(),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, String role) {
    return DrawerHeader(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Substation Manager Pro',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.appUser.email,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Text(
            'Role: $role',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// Substation User Home Screen
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
    // SubstationUserDashboardScreen will now contain its own Scaffold and AppBar
    return SubstationUserDashboardScreen(
      currentUser: widget.appUser,
      // Pass the common drawer to the dashboard screen
      drawer: _buildSubstationUserDrawer(context),
    );
  }

  Widget _buildSubstationUserDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context, 'Substation User'),
          const Divider(),
          _buildThemeToggle(context),
          const Divider(),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, String role) {
    return DrawerHeader(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Substation Manager Pro',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.appUser.email,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Text(
            'Role: $role',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// Subdivision Manager Home Screen
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
    // SubdivisionDashboardScreen will now contain its own Scaffold and AppBar
    return SubdivisionDashboardScreen(
      currentUser: widget.appUser,
      // Pass the common drawer to the dashboard screen
      drawer: _buildSubdivisionManagerDrawer(context),
    );
  }

  Widget _buildSubdivisionManagerDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context, 'Subdivision Manager'),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Subdivision Dashboard'),
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configure Charts'),
            onTap: () {
              Navigator.of(context).pop();
              if (widget.appUser.assignedLevels != null &&
                  widget.appUser.assignedLevels!.containsKey('subdivisionId')) {
                if (!mounted) return; // Add mounted check
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
                if (!mounted) return; // Add mounted check
                SnackBarUtils.showSnackBar(
                  context,
                  'No subdivision assigned to this user.',
                  isError: true,
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.flash_on),
            title: const Text('Energy SLD'),
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
                if (!mounted) return; // Add mounted check
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
                if (!mounted) return; // Add mounted check
                SnackBarUtils.showSnackBar(
                  context,
                  'No substation selected for Energy SLD.',
                  isError: true,
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View Saved SLDs'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SavedSldListScreen(currentUser: widget.appUser),
                ),
              );
            },
          ),
          const Divider(),
          _buildThemeToggle(context),
          const Divider(),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, String role) {
    return DrawerHeader(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Substation Manager Pro',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.appUser.email,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Text(
            'Role: $role',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// Common widgets for drawer
Widget _buildThemeToggle(BuildContext context) {
  final appStateData = Provider.of<AppStateData>(context, listen: false);
  return ListTile(
    leading: Icon(
      appStateData.themeMode == ThemeMode.light
          ? Icons.dark_mode
          : Icons.light_mode,
    ),
    title: const Text('Dark Mode'),
    trailing: Switch(
      value: appStateData.themeMode == ThemeMode.dark,
      onChanged: (value) {
        appStateData.toggleTheme();
      },
      activeColor: Theme.of(context).colorScheme.primary,
    ),
  );
}

Widget _buildLogoutTile(BuildContext context) {
  return ListTile(
    leading: const Icon(Icons.logout),
    title: const Text('Logout'),
    onTap: () async {
      Navigator.of(context).pop(); // Close drawer
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      // No need to navigate here, HomeRouter will react to auth state change
    },
  );
}
