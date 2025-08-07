// lib/screens/energy_sld_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../controllers/sld_controller.dart';
import '../../models/saved_sld_model.dart';
import '../../models/user_model.dart';
import '../../services/energy_data_service.dart';
import '../../utils/energy_sld_utils.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/energy_movement_controls_widget.dart';
import '../../widgets/energy_speed_dial_widget.dart';
import '../../widgets/energy_tables_widget.dart';
import '../../widgets/sld_view_widget.dart';

class EnergySldScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final SavedSld? savedSld;

  const EnergySldScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    this.savedSld,
  });

  @override
  State<EnergySldScreen> createState() => _EnergySldScreenState();
}

class _EnergySldScreenState extends State<EnergySldScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();
  bool _showTables = true;
  bool _isViewingSavedSld = false;
  late final EnergyDataService _energyDataService;

  @override
  void initState() {
    super.initState();
    _energyDataService = EnergyDataService(
      substationId: widget.substationId,
      currentUser: widget.currentUser,
    );
    _isViewingSavedSld = widget.savedSld != null;

    if (_isViewingSavedSld) {
      _initializeFromSavedSld();
    } else {
      _loadEnergyData();
    }
  }

  void _initializeFromSavedSld() {
    _startDate = widget.savedSld!.startDate.toDate();
    _endDate = widget.savedSld!.endDate.toDate();
    _loadEnergyData(fromSaved: true);
  }

  Future<void> _loadEnergyData({bool fromSaved = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final sldController = Provider.of<SldController>(context, listen: false);

      if (fromSaved && widget.savedSld != null) {
        await _energyDataService.loadFromSavedSld(
          widget.savedSld!,
          sldController,
        );
      } else {
        await _energyDataService.loadLiveEnergyData(
          _startDate,
          _endDate,
          sldController,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load energy data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    if (_isViewingSavedSld) return;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadEnergyData();
    }
  }

  // Enhanced back press handling with save/discard options
  Future<void> _handleBackPress() async {
    final sldController = Provider.of<SldController>(context, listen: false);

    // Check if there are unsaved changes
    if (sldController.hasUnsavedChanges()) {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.save_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text('Save Changes?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You have unsaved layout changes. What would you like to do?',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saving will update the layout for all users',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: Text(
                'Discard Changes',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save & Exit'),
            ),
          ],
        ),
      );

      if (result == 'save') {
        // Show loading dialog while saving
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text('Saving changes...'),
                ],
              ),
            ),
          ),
        );

        try {
          final success = await sldController.saveAllPendingChanges();

          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog

            if (success) {
              SnackBarUtils.showSnackBar(
                context,
                'Layout changes saved successfully!',
              );
              Navigator.of(context).pop(); // Go back to previous screen
            } else {
              SnackBarUtils.showSnackBar(
                context,
                'Failed to save changes. Please try again.',
                isError: true,
              );
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            SnackBarUtils.showSnackBar(
              context,
              'Error saving changes: $e',
              isError: true,
            );
          }
        }
      } else if (result == 'discard') {
        sldController.cancelLayoutChanges();
        SnackBarUtils.showSnackBar(context, 'Changes discarded');
        if (mounted) Navigator.of(context).pop();
      }
    } else {
      // No unsaved changes, go back directly
      Navigator.of(context).pop();
    }
  }

  String get _dateRangeText {
    if (_startDate.isAtSameMomentAs(_endDate)) {
      return DateFormat('dd-MMM-yyyy').format(_startDate);
    } else {
      return '${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.substationId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: _buildEmptyState(),
      );
    }

    final sldController = Provider.of<SldController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(sldController),
      body: Stack(
        children: [
          _isLoading ? _buildLoadingState() : _buildBody(sldController),
          // Position the speed dial widget in the stack for proper bottom-right placement
          _buildFloatingActionButton(sldController),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(sldController),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.electrical_services,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Substation Selected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a substation to view energy SLD.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading energy data...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch the latest information',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(SldController sldController) {
    final hasUnsavedChanges = sldController.hasUnsavedChanges();

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hasUnsavedChanges
                ? Colors.orange.withOpacity(0.1)
                : Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_back_ios,
            color: hasUnsavedChanges
                ? Colors.orange.shade700
                : Theme.of(context).colorScheme.primary,
            size: 18,
          ),
        ),
        onPressed: _handleBackPress,
        tooltip: hasUnsavedChanges
            ? 'Back (Unsaved Changes)'
            : 'Back to Dashboard',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Energy Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (hasUnsavedChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'MODIFIED',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            '${widget.substationName} ($_dateRangeText)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isViewingSavedSld
                  ? Colors.grey.withOpacity(0.1)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_today,
              color: _isViewingSavedSld
                  ? Colors.grey.shade600
                  : Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          onPressed: _isViewingSavedSld ? null : () => _selectDate(context),
          tooltip: _isViewingSavedSld
              ? 'Date range cannot be changed for saved SLD'
              : 'Change Date Range',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(SldController sldController) {
    return Column(
      children: [
        Expanded(
          child: SldViewWidget(
            isEnergySld: true,
            onBayTapped: (bay, tapPosition) {
              if (sldController.selectedBayForMovementId == null) {
                EnergySldUtils.showBayActions(
                  context,
                  bay,
                  tapPosition,
                  sldController,
                  _isViewingSavedSld,
                  _energyDataService,
                );
              }
            },
          ),
        ),
        if (_showTables)
          EnergyTablesWidget(
            isViewingSavedSld: _isViewingSavedSld,
            loadedAssessmentsSummary:
                _energyDataService.loadedAssessmentsSummary,
            allAssessmentsForDisplay:
                _energyDataService.allAssessmentsForDisplay,
          ),
      ],
    );
  }

  Widget _buildFloatingActionButton(SldController sldController) {
    return EnergySpeedDialWidget(
      isViewingSavedSld: _isViewingSavedSld,
      showTables: _showTables,
      onToggleTables: () => setState(() => _showTables = !_showTables),
      onSaveSld: () => EnergySldUtils.saveSld(
        context,
        widget.substationId,
        widget.substationName,
        widget.currentUser,
        _startDate,
        _endDate,
        sldController,
        _energyDataService.allAssessmentsForDisplay,
      ),
      onSharePdf: () => EnergySldUtils.shareAsPdf(
        context,
        widget.substationName,
        _startDate,
        _endDate,
        sldController,
        _energyDataService.allAssessmentsForDisplay,
        _isViewingSavedSld,
        _energyDataService.loadedAssessmentsSummary,
      ),
      onConfigureBusbar: () =>
          _energyDataService.showBusbarSelectionDialog(context, sldController),
      onAddAssessment: () => _energyDataService.showBaySelectionForAssessment(
        context,
        sldController,
      ),
    );
  }

  Widget? _buildBottomNavigationBar(SldController sldController) {
    if (sldController.selectedBayForMovementId == null) return null;

    return EnergyMovementControlsWidget(
      onSave: _loadEnergyData,
      isViewingSavedSld: _isViewingSavedSld,
    );
  }
}
