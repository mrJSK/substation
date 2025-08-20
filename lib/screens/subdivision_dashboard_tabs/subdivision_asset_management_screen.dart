import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../controllers/sld_controller.dart';
import '../../models/app_state_data.dart';
import '../../models/bay_model.dart';
import '../../models/equipment_model.dart';
import '../../models/hierarchy_models.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';
import 'busbar_configuration_screen.dart';
import 'substation_detail_screen.dart';
import 'export_master_data_screen.dart';

class SubdivisionAssetManagementScreen extends StatefulWidget {
  final String subdivisionId;
  final AppUser currentUser;

  const SubdivisionAssetManagementScreen({
    super.key,
    required this.subdivisionId,
    required this.currentUser,
  });

  @override
  State<SubdivisionAssetManagementScreen> createState() =>
      _SubdivisionAssetManagementScreenState();
}

class _SubdivisionAssetManagementScreenState
    extends State<SubdivisionAssetManagementScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Substation> _substationsInSubdivision = [];
  Substation? _selectedSubstation;

  Map<String, int> _bayTypeStats = {};
  Map<String, int> _equipmentTypeStats = {};
  int _totalBays = 0;
  int _totalEquipment = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fetchSubdivisionAssets();
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

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E) // Dark mode background
          : const Color(0xFFFAFAFA),
      body: Column(
        children: [
          _buildConfigurationSection(theme, isDarkMode),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? _buildLoadingState(theme, isDarkMode)
                : _buildMainContent(theme, isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.white,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.electrical_services,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Manage Substation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSubstationSelector(theme, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildSubstationSelector(ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Substation',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Substation>(
              value: _selectedSubstation,
              isExpanded: true,
              dropdownColor: isDarkMode
                  ? const Color(0xFF2C2C2E)
                  : Colors.white,
              items: [
                DropdownMenuItem<Substation>(
                  value: null,
                  child: Text(
                    'All Substations',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ..._substationsInSubdivision.map((substation) {
                  return DropdownMenuItem(
                    value: substation,
                    child: Text(
                      substation.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ],
              onChanged: (Substation? newValue) {
                setState(() {
                  _selectedSubstation = newValue;
                });
                _calculateStatsForSelectedSubstation();
              },
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              hint: Text(
                'Select Substation',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Asset Management',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme, bool isDarkMode) {
    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _fetchSubdivisionAssets,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(theme, isDarkMode),
            const SizedBox(height: 20),
            _buildActionCards(theme, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme, bool isDarkMode) {
    if (_totalBays == 0 && _totalEquipment == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
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
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                size: 40,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No Assets Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedSubstation != null
                    ? 'No bays or equipment found in ${_selectedSubstation!.name}'
                    : 'No bays or equipment found in subdivision substations',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedSubstation != null
              ? 'Assets in ${_selectedSubstation!.name}'
              : 'Assets in All Substations',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_selectedSubstation == null)
              Expanded(
                child: _buildStatCard(
                  theme: theme,
                  title: 'Total Substations',
                  value: '${_substationsInSubdivision.length}',
                  icon: Icons.electrical_services,
                  color: Colors.blue,
                  isDarkMode: isDarkMode,
                ),
              ),
            if (_selectedSubstation == null) const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme: theme,
                title: 'Total Bays',
                value: '$_totalBays',
                icon: Icons.settings,
                color: Colors.green,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme: theme,
                title: 'Total Equipment',
                value: '$_totalEquipment',
                icon: Icons.construction,
                color: Colors.orange,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),

        if (_bayTypeStats.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Bay Types',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildBayTypeStats(theme, isDarkMode),
        ],

        if (_equipmentTypeStats.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Equipment Types',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildEquipmentTypeStats(theme, isDarkMode),
        ],
      ],
    );
  }

  Widget _buildBayTypeStats(ThemeData theme, bool isDarkMode) {
    final colors = [
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.red,
      Colors.amber,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _bayTypeStats.entries.map((entry) {
        final color =
            colors[_bayTypeStats.keys.toList().indexOf(entry.key) %
                colors.length];
        return _buildStatCard(
          theme: theme,
          title: '${entry.key} Bays',
          value: '${entry.value}',
          icon: Icons.settings_input_component,
          color: color,
          isCompact: true,
          isDarkMode: isDarkMode,
        );
      }).toList(),
    );
  }

  Widget _buildEquipmentTypeStats(ThemeData theme, bool isDarkMode) {
    final colors = [
      Colors.cyan,
      Colors.pink,
      Colors.brown,
      Colors.lime,
      Colors.deepOrange,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _equipmentTypeStats.entries.map((entry) {
        final color =
            colors[_equipmentTypeStats.keys.toList().indexOf(entry.key) %
                colors.length];
        return _buildStatCard(
          theme: theme,
          title: entry.key,
          value: '${entry.value}',
          icon: Icons.precision_manufacturing,
          color: color,
          isCompact: true,
          isDarkMode: isDarkMode,
        );
      }).toList(),
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isCompact = false,
    required bool isDarkMode,
  }) {
    return Container(
      width: isCompact ? 140 : null,
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.white,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: isCompact ? 32 : 36,
                height: isCompact ? 32 : 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isCompact ? 16 : 18),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isCompact ? 11 : 13,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          theme: theme,
          icon: Icons.electrical_services,
          title: 'Manage Bays & Equipment',
          subtitle: _selectedSubstation != null
              ? 'View and manage assets in ${_selectedSubstation!.name}'
              : 'Select a specific substation to manage its assets',
          color: theme.colorScheme.primary,
          onTap: _selectedSubstation != null
              ? () => _navigateToSubstationDetail(_selectedSubstation!)
              : null,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 12),
        // ✅ NEW: Configure Busbar Action
        _buildActionCard(
          theme: theme,
          icon: Icons.settings,
          title: 'Configure Busbar',
          subtitle: _selectedSubstation != null
              ? 'Configure energy mappings for ${_selectedSubstation!.name}\'s busbars'
              : 'Select a substation to configure busbar energy mappings',
          color: Colors.orange,
          onTap: _selectedSubstation != null
              ? () => _navigateToBusbarConfiguration(_selectedSubstation!)
              : null,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          theme: theme,
          icon: Icons.download,
          title: 'Export Master Data',
          subtitle: _selectedSubstation != null
              ? 'Generate CSV report for ${_selectedSubstation!.name}'
              : 'Generate comprehensive CSV reports of your assets',
          color: Colors.green,
          onTap: () => _navigateToExportScreen(),
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  // ✅ FIXED: Enhanced navigation with proper debugging and initialization
  void _navigateToBusbarConfiguration(Substation substation) async {
    _animationController.forward();

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Initialize SLD controller
      final sldController = SldController(
        substationId: substation.id,
        transformationController: TransformationController(),
      );

      // Wait for proper initialization with detailed logging
      await _waitForSldControllerWithDebug(sldController);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // ✅ DEBUG: Check bay data before showing dialog
      print('DEBUG: Total bays loaded: ${sldController.allBays.length}');
      for (var bay in sldController.allBays) {
        print(
          'DEBUG: Bay - Name: ${bay.name}, Type: ${bay.bayType}, ID: ${bay.id}',
        );
      }

      // Get busbars with debug info
      final busbars = sldController.allBays
          .where((bay) => bay.bayType.toLowerCase() == 'busbar')
          .toList();

      print('DEBUG: Found ${busbars.length} busbars');

      if (busbars.isEmpty) {
        // ✅ FALLBACK: Show all bays if no busbars found
        SnackBarUtils.showSnackBar(
          context,
          'No busbars found. Showing all bays for configuration.',
        );
        _showAllBaysSelectionDialog(context, substation, sldController);
      } else {
        _showBusbarSelectionDialog(context, substation, sldController);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      SnackBarUtils.showSnackBar(
        context,
        'Failed to load substation data: $e',
        isError: true,
      );
      print('ERROR: Navigation failed - $e');
    } finally {
      _animationController.reverse();
    }
  }

  // ✅ ENHANCED: Wait with detailed debugging
  Future<void> _waitForSldControllerWithDebug(
    SldController sldController,
  ) async {
    int attempts = 0;
    const maxAttempts = 30; // Increased timeout

    print('DEBUG: Starting SLD controller initialization...');

    while (attempts < maxAttempts) {
      print('DEBUG: Initialization attempt ${attempts + 1}/$maxAttempts');
      print('DEBUG: Controller initialized: ${sldController.isInitialized}');
      print('DEBUG: Bays count: ${sldController.allBays.length}');

      if (sldController.isInitialized && sldController.allBays.isNotEmpty) {
        print(
          'DEBUG: ✅ SLD Controller ready with ${sldController.allBays.length} bays',
        );
        return;
      }

      attempts++;
      await Future.delayed(
        const Duration(milliseconds: 1000),
      ); // Increased delay
    }

    print(
      'ERROR: ❌ SLD Controller initialization timeout after $maxAttempts attempts',
    );
    throw Exception(
      'SLD Controller initialization timeout - no bay data loaded',
    );
  }

  // ✅ NEW: Fallback dialog showing all bays
  void _showAllBaysSelectionDialog(
    BuildContext context,
    Substation substation,
    SldController sldController,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final allBays = sldController.allBays
        .where((bay) => bay.id.isNotEmpty)
        .toList();

    if (allBays.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No bays found in ${substation.name}',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Select Bay to Configure',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: math.min(400, allBays.length * 80.0),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allBays.length,
            itemBuilder: (context, index) {
              final bay = allBays[index];
              final connectedBays = _getConnectedBaysForBusbar(
                bay,
                sldController,
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getBayTypeColor(bay.bayType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getBayTypeIcon(bay.bayType),
                      color: _getBayTypeColor(bay.bayType),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    bay.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '${bay.bayType} • Connected: ${connectedBays.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToBusbarConfigurationScreen(
                      bay,
                      connectedBays,
                      sldController,
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ENHANCED: Busbar selection with better debugging
  void _showBusbarSelectionDialog(
    BuildContext context,
    Substation substation,
    SldController sldController,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final busbars = sldController.allBays
        .where((bay) => bay.bayType.toLowerCase() == 'busbar')
        .toList();

    // ✅ DEBUG: Log detailed busbar information
    print('DEBUG: Showing busbar dialog with ${busbars.length} busbars:');
    for (var i = 0; i < busbars.length; i++) {
      final busbar = busbars[i];
      print(
        'DEBUG: Busbar $i: ${busbar.name} (${busbar.voltageLevel}) - ID: ${busbar.id}',
      );
    }

    if (busbars.isEmpty) {
      print('ERROR: No busbars found - this should not happen here');
      SnackBarUtils.showSnackBar(
        context,
        'No busbars found in ${substation.name}',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Busbar to Configure',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${busbars.length} busbars found',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: math.min(400, busbars.length * 80.0 + 50),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: busbars.length,
            itemBuilder: (context, index) {
              final busbar = busbars[index];
              final connectedBays = _getConnectedBaysForBusbar(
                busbar,
                sldController,
              );
              final nonBusbarBays = connectedBays
                  .where((bay) => bay.bayType != 'Busbar')
                  .length;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.electrical_services,
                      color: Colors.blue,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    '${busbar.voltageLevel} ${busbar.name}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Connected bays: $nonBusbarBays',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    print('DEBUG: Selected busbar: ${busbar.name}');
                    Navigator.pop(context);
                    _navigateToBusbarConfigurationScreen(
                      busbar,
                      connectedBays,
                      sldController,
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Navigate to the actual configuration screen
  void _navigateToBusbarConfigurationScreen(
    Bay selectedBusbar,
    List<Bay> connectedBays,
    SldController sldController,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: sldController,
          child: BusbarConfigurationScreen(
            busbar: selectedBusbar,
            connectedBays: connectedBays,
            allSubstationBays: sldController.allBays,
            currentConfiguration: null,
            substationConfiguration: null,
            onSaveConfiguration: (busbarConfig, substationConfig) async {
              try {
                // Here you would integrate with EnergyDataService to save configurations
                // For now, just show success message
                SnackBarUtils.showSnackBar(
                  context,
                  'Configuration saved for ${selectedBusbar.name}!',
                );
              } catch (e) {
                SnackBarUtils.showSnackBar(
                  context,
                  'Failed to save configuration: $e',
                  isError: true,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Helper method to get connected bays for a busbar
  List<Bay> _getConnectedBaysForBusbar(
    Bay busbar,
    SldController sldController,
  ) {
    final connectedBays = <Bay>[];

    for (var bay in sldController.allBays) {
      if (bay.bayType == 'Busbar') continue;

      // Simple voltage-based connection logic
      if (busbar.voltageLevel == '132kV') {
        if (bay.bayType == 'Transformer' || bay.bayType == 'Line') {
          connectedBays.add(bay);
        }
      } else if (busbar.voltageLevel == '33kV') {
        if (bay.bayType == 'Transformer' || bay.bayType == 'Feeder') {
          connectedBays.add(bay);
        }
      }
    }

    return connectedBays;
  }

  // ✅ HELPER: Get bay type color
  Color _getBayTypeColor(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Colors.purple;
      case 'line':
        return Colors.blue;
      case 'feeder':
        return Colors.orange;
      case 'busbar':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // ✅ HELPER: Get bay type icon
  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.transform;
      case 'line':
        return Icons.power_input;
      case 'feeder':
        return Icons.cable;
      case 'busbar':
        return Icons.electrical_services;
      default:
        return Icons.settings;
    }
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
    required bool isDarkMode,
  }) {
    final isDisabled = onTap == null;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 - (_animationController.value * 0.02),
          child: Container(
            decoration: BoxDecoration(
              color: isDisabled
                  ? (isDarkMode
                        ? const Color(0xFF3C3C3E)
                        : Colors.grey.shade100)
                  : (isDarkMode ? const Color(0xFF2C2C2E) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDisabled
                    ? (isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade300)
                    : (isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade200),
              ),
              boxShadow: isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: InkWell(
              onTap: isDisabled ? null : onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? (isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.shade300)
                            : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isDisabled
                            ? (isDarkMode
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.grey.shade500)
                            : color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDisabled
                                  ? (isDarkMode
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.grey.shade500)
                                  : (isDarkMode
                                        ? Colors.white
                                        : theme.colorScheme.onSurface),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDisabled
                                  ? (isDarkMode
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.grey.shade400)
                                  : (isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey.shade600),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDisabled)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToSubstationDetail(Substation substation) {
    _animationController.forward();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (context) => SldController(
            substationId: substation.id,
            transformationController: TransformationController(),
          ),
          child: SubstationDetailScreen(
            substationId: substation.id,
            substationName: substation.name,
            currentUser: widget.currentUser,
          ),
        ),
      ),
    );
    _animationController.reverse();
  }

  void _navigateToExportScreen() {
    _animationController.forward();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExportMasterDataScreen(
          currentUser: widget.currentUser,
          subdivisionId: widget.subdivisionId,
        ),
      ),
    );
    _animationController.reverse();
  }

  Future<void> _fetchSubdivisionAssets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: widget.subdivisionId)
          .orderBy('name')
          .get();

      _substationsInSubdivision = substationsSnapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();

      if (_substationsInSubdivision.isNotEmpty && _selectedSubstation == null) {
        _selectedSubstation = _substationsInSubdivision.first;
      }

      await _calculateStatsForSelectedSubstation();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load assets: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateStatsForSelectedSubstation() async {
    try {
      List<String> substationIds;

      if (_selectedSubstation != null) {
        substationIds = [_selectedSubstation!.id];
      } else {
        substationIds = _substationsInSubdivision.map((s) => s.id).toList();
      }

      if (substationIds.isNotEmpty) {
        final baysSnapshot = await FirebaseFirestore.instance
            .collection('bays')
            .where('substationId', whereIn: substationIds)
            .get();

        final bays = baysSnapshot.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();

        _bayTypeStats.clear();
        for (final bay in bays) {
          _bayTypeStats[bay.bayType] = (_bayTypeStats[bay.bayType] ?? 0) + 1;
        }
        _totalBays = bays.length;

        if (bays.isNotEmpty) {
          final bayIds = bays.map((b) => b.id).toList();

          List<EquipmentInstance> allEquipment = [];
          for (int i = 0; i < bayIds.length; i += 10) {
            final chunk = bayIds.sublist(
              i,
              (i + 10 < bayIds.length) ? i + 10 : bayIds.length,
            );
            final equipmentSnapshot = await FirebaseFirestore.instance
                .collection('equipmentInstances')
                .where('bayId', whereIn: chunk)
                .where('status', isEqualTo: 'active')
                .get();

            allEquipment.addAll(
              equipmentSnapshot.docs.map(
                (doc) => EquipmentInstance.fromFirestore(doc),
              ),
            );
          }

          _equipmentTypeStats.clear();
          for (final equipment in allEquipment) {
            _equipmentTypeStats[equipment.equipmentTypeName] =
                (_equipmentTypeStats[equipment.equipmentTypeName] ?? 0) + 1;
          }
          _totalEquipment = allEquipment.length;
        } else {
          _equipmentTypeStats.clear();
          _totalEquipment = 0;
        }
      } else {
        _bayTypeStats.clear();
        _equipmentTypeStats.clear();
        _totalBays = 0;
        _totalEquipment = 0;
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Error calculating stats: $e');
    }
  }
}
