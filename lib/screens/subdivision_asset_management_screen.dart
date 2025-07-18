// lib/screens/subdivision_asset_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import './substation_detail_screen.dart';
import 'export_master_data_screen.dart';
import '../controllers/sld_controller.dart';

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
      duration: const Duration(milliseconds: 300),
    );
    _fetchSubstationsInSubdivision();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load substations: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Substation',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                semanticsLabel: 'Select Substation Dialog',
              ),
              const SizedBox(height: 16),
              DropdownSearch<Substation>(
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: 'Search substations...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                items: _substationsInSubdivision,
                itemAsString: (s) => s.name,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Substation',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                ),
                onChanged: (Substation? selected) {
                  Navigator.of(context).pop(selected);
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Substations...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    semanticsLabel: 'Loading Substations',
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _fetchSubstationsInSubdivision,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asset Management',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      semanticsLabel: 'Asset Management Title',
                    ),
                    const SizedBox(height: 24),
                    _buildActionCard(
                      context,
                      icon: Icons.electrical_services,
                      title: 'Manage Bays & Equipment',
                      subtitle:
                          'View and manage assets within your substations',
                      onTap: () async {
                        _animationController.forward();
                        final selectedSubstation =
                            await _showSubstationSelectionDialog();
                        if (selectedSubstation != null && mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChangeNotifierProvider(
                                create: (context) => SldController(
                                  substationId: selectedSubstation.id,
                                  transformationController:
                                      TransformationController(),
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
                      context,
                      icon: Icons.download,
                      title: 'Export Master Data',
                      subtitle: 'Generate CSV reports of your assets',
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
                ),
              ),
            ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.98).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOut,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                    semanticLabel: title,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
