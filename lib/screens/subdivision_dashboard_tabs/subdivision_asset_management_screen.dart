// lib/screens/subdivision_asset_management_screen.dart

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
import 'substation_detail_screen.dart';
import '../export_master_data_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _isLoading ? _buildLoadingState(theme) : _buildMainContent(theme),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
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
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _fetchSubdivisionAssets,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(theme),
            const SizedBox(height: 20), // Reduced spacing
            _buildActionCards(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    // If no data, don't show any stats
    if (_totalBays == 0 && _totalEquipment == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
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
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No Assets Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No bays or equipment found in subdivision substations',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
        // Overview stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme: theme,
                title: 'Total Substations',
                value: '${_substationsInSubdivision.length}',
                icon: Icons.electrical_services,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme: theme,
                title: 'Total Bays',
                value: '$_totalBays',
                icon: Icons.settings,
                color: Colors.green,
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
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildBayTypeStats(theme),
        ],

        if (_equipmentTypeStats.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Equipment Types',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildEquipmentTypeStats(theme),
        ],
      ],
    );
  }

  Widget _buildBayTypeStats(ThemeData theme) {
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
        );
      }).toList(),
    );
  }

  Widget _buildEquipmentTypeStats(ThemeData theme) {
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
  }) {
    return Container(
      width: isCompact ? 140 : null,
      padding: EdgeInsets.all(
        isCompact ? 12 : 16,
      ), // Smaller padding for compact cards
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: isCompact ? 32 : 36, // Smaller for compact
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
              fontSize: isCompact ? 18 : 20, // Smaller for compact
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isCompact ? 11 : 13, // Smaller for compact
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(ThemeData theme) {
    final appState = Provider.of<AppStateData>(context);
    final selectedSubstation = appState.selectedSubstation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16, // Reduced font size
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12), // Reduced spacing
        _buildActionCard(
          theme: theme,
          icon: Icons.electrical_services,
          title: 'Manage Bays & Equipment',
          subtitle: selectedSubstation != null
              ? 'View and manage assets in ${selectedSubstation.name}'
              : 'Select a substation from the app bar to manage assets',
          color: theme.colorScheme.primary,
          onTap: selectedSubstation != null
              ? () => _navigateToSubstationDetail(selectedSubstation)
              : null,
        ),
        const SizedBox(height: 12), // Reduced spacing
        _buildActionCard(
          theme: theme,
          icon: Icons.download,
          title: 'Export Master Data',
          subtitle: 'Generate comprehensive CSV reports of your assets',
          color: Colors.green,
          onTap: () => _navigateToExportScreen(),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 - (_animationController.value * 0.02),
          child: Container(
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade200,
              ),
              boxShadow: isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: InkWell(
              onTap: isDisabled ? null : onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16), // Reduced padding
                child: Row(
                  children: [
                    Container(
                      width: 44, // Reduced size
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? Colors.grey.shade300
                            : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isDisabled ? Colors.grey.shade500 : color,
                        size: 20, // Reduced icon size
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
                              fontSize: 15, // Reduced font size
                              fontWeight: FontWeight.w600,
                              color: isDisabled
                                  ? Colors.grey.shade500
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13, // Reduced font size
                              color: isDisabled
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDisabled)
                      Container(
                        width: 28, // Reduced size
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 12, // Reduced icon size
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
      // Fetch substations in subdivision
      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: widget.subdivisionId)
          .orderBy('name')
          .get();

      _substationsInSubdivision = substationsSnapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();

      if (_substationsInSubdivision.isNotEmpty) {
        // Get all substation IDs
        final substationIds = _substationsInSubdivision
            .map((s) => s.id)
            .toList();

        // Fetch bays for all substations
        final baysSnapshot = await FirebaseFirestore.instance
            .collection('bays')
            .where('substationId', whereIn: substationIds)
            .get();

        final bays = baysSnapshot.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();

        // Calculate bay type stats
        _bayTypeStats.clear();
        for (final bay in bays) {
          _bayTypeStats[bay.bayType] = (_bayTypeStats[bay.bayType] ?? 0) + 1;
        }
        _totalBays = bays.length;

        // Fetch equipment for all bays
        if (bays.isNotEmpty) {
          final bayIds = bays.map((b) => b.id).toList();

          // Query equipment instances in chunks of 10 (Firestore limit)
          List<EquipmentInstance> allEquipment = [];
          for (int i = 0; i < bayIds.length; i += 10) {
            final chunk = bayIds.sublist(
              i,
              (i + 10 < bayIds.length) ? i + 10 : bayIds.length,
            );
            final equipmentSnapshot = await FirebaseFirestore.instance
                .collection('equipmentInstances')
                .where('bayId', whereIn: chunk)
                .where(
                  'status',
                  isEqualTo: 'active',
                ) // Only count active equipment
                .get();

            allEquipment.addAll(
              equipmentSnapshot.docs.map(
                (doc) => EquipmentInstance.fromFirestore(doc),
              ),
            );
          }

          // Calculate equipment type stats
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
}
