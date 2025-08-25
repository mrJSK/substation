import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/modern_app_drawer.dart';
import 'admin_hierarchy_screen.dart';
import 'master_equipment_management_screen.dart';
import 'upload_master_data.dart';
import 'user_management_screen.dart';
import 'reading_template_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppUser adminUser;

  const AdminDashboardScreen({super.key, required this.adminUser});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoadingStats = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      body: _buildBody(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 0,
      title: Text(
        'Admin Dashboard',
        style: TextStyle(
          color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.menu,
          color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
        ),
        onPressed: () {
          print('Menu button pressed');
          if (mounted) {
            ModernAppDrawer.show(context, widget.adminUser);
          } else {
            print('Context is not mounted');
          }
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      color: isDarkMode ? Colors.blue[300] : Colors.blue,
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : null,
      onRefresh: _loadDashboardStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingStats)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(
                    color: isDarkMode ? Colors.blue[300] : Colors.blue,
                  ),
                ),
              )
            else ...[
              _buildAdminFunctionsSection(theme),
              const SizedBox(height: 32),

              if (_stats['userStats'] != null &&
                  _stats['userStats'].isNotEmpty) ...[
                _buildUserStatsSection(theme),
                const SizedBox(height: 32),
              ],

              _buildTemplatesSection(theme),
              const SizedBox(height: 32),

              if (_stats['voltageStats'] != null &&
                  _stats['voltageStats'].isNotEmpty)
                _buildVoltageStatsSection(theme),

              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: isDarkMode
              ? Colors.black.withOpacity(0.3)
              : Colors.black.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildAdminFunctionsSection(ThemeData theme) {
    final functions = _getAdminFunctions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Admin Functions', theme),
        Column(
          children: functions.map((function) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: _buildFunctionCard(function, theme),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFunctionCard(Map<String, dynamic> function, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => function['screen']),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _buildCardDecoration(),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: function['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(function['icon'], color: function['color'], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    function['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    function['subtitle'],
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            if (function['badge'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: function['badgeColor'],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  function['badge'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatsSection(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final userStats = _stats['userStats'] as Map<String, int>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionHeader('Users by Category', theme)),
            if ((_stats['pendingUsers'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_stats['pendingUsers']} Pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: userStats.length,
            itemBuilder: (context, index) {
              final entry = userStats.entries.elementAt(index);
              return Container(
                width: 150,
                margin: EdgeInsets.only(
                  right: index < userStats.length - 1 ? 16 : 0,
                ),
                child: _buildUserStatCard(entry.key, entry.value, theme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserStatCard(String role, int count, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final roleInfo = _getRoleInfo(role);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: roleInfo['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  roleInfo['icon'],
                  color: roleInfo['color'],
                  size: 16,
                ),
              ),
              const Spacer(),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: roleInfo['color'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              roleInfo['label'],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Templates', theme),
        SizedBox(
          height: 90,
          child: Row(
            children: [
              Expanded(
                child: _buildTemplateStatCard(
                  'Equipments',
                  _stats['equipmentTemplates'] ?? 0,
                  Icons.construction,
                  Colors.orange,
                  theme,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTemplateStatCard(
                  'Readings',
                  _stats['readingTemplates'] ?? 0,
                  Icons.rule,
                  Colors.purple,
                  theme,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateStatCard(
    String label,
    int count,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoltageStatsSection(ThemeData theme) {
    final voltageStats = _stats['voltageStats'] as Map<String, int>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Substations by Voltage Level', theme),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: voltageStats.length,
            itemBuilder: (context, index) {
              final entry = voltageStats.entries.elementAt(index);
              return Container(
                width: 150,
                margin: EdgeInsets.only(
                  right: index < voltageStats.length - 1 ? 16 : 0,
                ),
                child: _buildVoltageStatCard(entry.key, entry.value, theme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVoltageStatCard(String voltage, int count, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _buildCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.blue[800]?.withOpacity(0.3)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.electrical_services,
                    color: isDarkMode ? Colors.blue[300] : Colors.blue.shade700,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$voltage Substations',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.blue[300] : Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAdminFunctions() {
    return [
      {
        'title': 'User Management',
        'subtitle': 'Approve users and assign roles',
        'icon': Icons.people,
        'screen': const UserManagementScreen(),
        'color': Colors.blue,
        'badge': (_stats['pendingUsers'] ?? 0) > 0
            ? '${_stats['pendingUsers']}'
            : null,
        'badgeColor': Colors.orange,
      },
      {
        'title': 'System Hierarchy',
        'subtitle': 'Manage organizational structure',
        'icon': Icons.account_tree,
        'screen': const AdminHierarchyScreen(),
        'color': Colors.green,
      },
      {
        'title': 'Equipment Templates',
        'subtitle': 'Define equipment types and properties',
        'icon': Icons.construction,
        'screen': const MasterEquipmentScreen(),
        'color': Colors.orange,
      },
      {
        'title': 'Reading Templates',
        'subtitle': 'Configure reading parameters',
        'icon': Icons.rule,
        'screen': const ReadingTemplateManagementScreen(),
        'color': Colors.purple,
      },
      {
        'title': 'Upload Master Data',
        'subtitle': 'Upload Vendor, Material, or Service data',
        'icon': Icons.upload_file,
        'screen': const UploadMasterDataScreen(),
        'color': Colors.teal,
      },
    ];
  }

  Map<String, dynamic> _getRoleInfo(String role) {
    switch (role) {
      case 'admin':
        return {
          'label': 'Admins',
          'icon': Icons.admin_panel_settings,
          'color': Colors.red,
        };
      case 'subdivisionManager':
        return {
          'label': 'Subdivision Managers',
          'icon': Icons.apartment,
          'color': Colors.purple,
        };
      case 'substationUser':
        return {
          'label': 'Substation Users',
          'icon': Icons.electrical_services,
          'color': Colors.teal,
        };
      case 'divisionManager':
        return {
          'label': 'Division Managers',
          'icon': Icons.corporate_fare,
          'color': Colors.orange,
        };
      case 'circleManager':
        return {
          'label': 'Circle Managers',
          'icon': Icons.circle,
          'color': Colors.green,
        };
      case 'zoneManager':
        return {
          'label': 'Zone Managers',
          'icon': Icons.domain,
          'color': Colors.cyan,
        };
      default:
        return {'label': role, 'icon': Icons.person, 'color': Colors.grey};
    }
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final results = await Future.wait([
        _loadVoltageStats(),
        _loadUserStats(),
        _loadSystemStats(),
      ]);

      setState(() {
        _stats = {...results[0], ...results[1], ...results[2]};
        _isLoadingStats = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load stats: $e',
          isError: true,
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadVoltageStats() async {
    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .get();

    Map<String, int> voltageStats = {};
    int totalSubstations = 0;

    for (var doc in substationsSnapshot.docs) {
      final data = doc.data();
      final voltage = data['voltageLevel'] as String? ?? 'Unknown';
      voltageStats[voltage] = (voltageStats[voltage] ?? 0) + 1;
      totalSubstations++;
    }

    return {'voltageStats': voltageStats, 'totalSubstations': totalSubstations};
  }

  Future<Map<String, dynamic>> _loadUserStats() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();

    Map<String, int> userStats = {};
    int pendingUsers = 0;

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final role = data['role'] as String? ?? 'pending';
      final approved = data['approved'] as bool? ?? false;

      if (!approved) {
        pendingUsers++;
      } else {
        userStats[role] = (userStats[role] ?? 0) + 1;
      }
    }

    userStats.removeWhere((key, value) => value == 0);

    return {'userStats': userStats, 'pendingUsers': pendingUsers};
  }

  Future<Map<String, dynamic>> _loadSystemStats() async {
    final equipmentTemplatesSnapshot = await FirebaseFirestore.instance
        .collection('masterEquipmentTemplates')
        .get();

    final readingTemplatesSnapshot = await FirebaseFirestore.instance
        .collection('readingTemplates')
        .get();

    return {
      'equipmentTemplates': equipmentTemplatesSnapshot.docs.length,
      'readingTemplates': readingTemplatesSnapshot.docs.length,
    };
  }
}
