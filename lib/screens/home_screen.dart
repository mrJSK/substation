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
import '../screens/energy_sld_screen.dart';
import '../screens/saved_sld_list_screen.dart';
import '../screens/substation_user_dashboard_screen.dart';
import '../screens/subdivision_dashboard_screen.dart';
import '../screens/admin/reading_template_management_screen.dart';
import '../screens/readings_configuration_screen.dart';
import '../controllers/sld_controller.dart';
import '../utils/snackbar_utils.dart';

// Base Home Screen class for shared functionality
abstract class BaseHomeScreen extends StatefulWidget {
  final AppUser appUser;

  const BaseHomeScreen({super.key, required this.appUser});

  @override
  BaseHomeScreenState createState();
}

abstract class BaseHomeScreenState<T extends BaseHomeScreen> extends State<T> {
  Widget buildDrawer(BuildContext context);

  List<Widget> buildAppBarActions(BuildContext context) => [];

  @override
  Widget build(BuildContext context) {
    final appStateData = Provider.of<AppStateData>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(getAppBarTitle()),
        centerTitle: true,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            );
          },
        ),
        actions: buildAppBarActions(context),
      ),
      drawer: buildDrawer(context),
      body: buildBody(context),
    );
  }

  String getAppBarTitle();

  Widget buildBody(BuildContext context);
}

// Admin Home Screen
class AdminHomeScreen extends BaseHomeScreen {
  static const String routeName = '/admin_home';

  const AdminHomeScreen({super.key, required super.appUser});

  @override
  BaseHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends BaseHomeScreenState<AdminHomeScreen> {
  @override
  String getAppBarTitle() => 'Admin Dashboard';

  @override
  Widget buildBody(BuildContext context) {
    return AdminDashboardScreen(adminUser: widget.appUser);
  }

  @override
  Widget buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context),
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

  Widget _buildDrawerHeader(BuildContext context) {
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
            'Role: Admin',
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
  String getAppBarTitle() => 'Substation Dashboard';

  @override
  Widget buildBody(BuildContext context) {
    return SubstationUserDashboardScreen(currentUser: widget.appUser);
  }

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.flash_on),
        tooltip: 'Energy SLD',
        onPressed: () async {
          Substation? substationToView;
          if (widget.appUser.assignedLevels != null &&
              widget.appUser.assignedLevels!.containsKey('substationId')) {
            final substationDoc = await FirebaseFirestore.instance
                .collection('substations')
                .doc(widget.appUser.assignedLevels!['substationId'])
                .get();
            if (substationDoc.exists) {
              substationToView = Substation.fromFirestore(substationDoc);
            }
          }

          if (substationToView != null && context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider<SldController>(
                  create: (context) => SldController(
                    substationId: substationToView!.id,
                    transformationController: TransformationController(),
                  ),
                  child: EnergySldScreen(
                    substationId: substationToView!.id,
                    substationName: substationToView.name,
                    currentUser: widget.appUser,
                  ),
                ),
              ),
            );
          } else if (context.mounted) {
            SnackBarUtils.showSnackBar(
              context,
              'No substation assigned for Energy SLD.',
              isError: true,
            );
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.history),
        tooltip: 'View Saved SLDs',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  SavedSldListScreen(currentUser: widget.appUser),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context),
          const Divider(),
          _buildThemeToggle(context),
          const Divider(),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
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
            'Role: Substation User',
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
  String getAppBarTitle() => 'Subdivision Dashboard';

  @override
  Widget buildBody(BuildContext context) {
    return SubdivisionDashboardScreen(currentUser: widget.appUser);
  }

  @override
  Widget buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(context),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Subdivision Dashboard'),
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configure Readings'),
            onTap: () {
              Navigator.of(context).pop();
              if (widget.appUser.assignedLevels != null &&
                  widget.appUser.assignedLevels!.containsKey('subdivisionId')) {
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

  Widget _buildDrawerHeader(BuildContext context) {
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
            'Role: Subdivision Manager',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

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
      Navigator.of(context).pop();
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
    },
  );
}
