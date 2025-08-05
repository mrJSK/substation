// lib/screens/subdivision_asset_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../models/hierarchy_models.dart';
import '../../../utils/snackbar_utils.dart';
import 'substation_detail_screen.dart';
import '../export_master_data_screen.dart';
import '../../controllers/sld_controller.dart';

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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fetchSubstationsInSubdivision();
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
      onRefresh: _fetchSubstationsInSubdivision,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(theme),
            const SizedBox(height: 32),
            _buildStatsCards(theme),
            const SizedBox(height: 32),
            _buildActionCards(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asset Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage and monitor your electrical infrastructure assets',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(ThemeData theme) {
    return Row(
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
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            theme: theme,
            title: 'Active Assets',
            value: '${_substationsInSubdivision.length * 8}', // Estimated
            icon: Icons.settings,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          theme: theme,
          icon: Icons.electrical_services,
          title: 'Manage Bays & Equipment',
          subtitle: 'View and manage assets within your substations',
          color: theme.colorScheme.primary,
          onTap: () async {
            _animationController.forward();
            final selectedSubstation = await _showSubstationSelectionDialog();
            if (selectedSubstation != null && mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider(
                    create: (context) => SldController(
                      substationId: selectedSubstation.id,
                      transformationController: TransformationController(),
                    ),
                    child: SubstationDetailScreen(
                      substationId: selectedSubstation.id,
                      substationName: selectedSubstation.name,
                      currentUser: widget.currentUser,
                    ),
                  ),
                ),
              );
            }
            _animationController.reverse();
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          theme: theme,
          icon: Icons.download,
          title: 'Export Master Data',
          subtitle: 'Generate comprehensive CSV reports of your assets',
          color: Colors.green,
          onTap: () {
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
          },
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
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 - (_animationController.value * 0.02),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
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

  Future<Substation?> _showSubstationSelectionDialog() async {
    if (_substationsInSubdivision.isEmpty) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'No substations found in this subdivision.',
          isError: true,
        );
      }
      return null;
    }

    return await showModalBottomSheet<Substation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Substation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownSearch<Substation>(
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: 'Search substations...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                items: _substationsInSubdivision,
                itemAsString: (s) => s.name,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Choose Substation',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                onChanged: (Substation? selected) {
                  Navigator.of(context).pop(selected);
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchSubstationsInSubdivision() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: widget.subdivisionId)
          .orderBy('name')
          .get();

      _substationsInSubdivision = snapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load substations: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
