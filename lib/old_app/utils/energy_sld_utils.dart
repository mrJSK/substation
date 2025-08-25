import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../enums/movement_mode.dart';
import '../models/user_model.dart';
import '../models/bay_model.dart';
import '../models/saved_sld_model.dart';
import '../models/assessment_model.dart';
import '../controllers/sld_controller.dart';
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart';
import '../services/energy_data_service.dart';
import '../widgets/energy_assessment_dialog.dart';
import '../utils/snackbar_utils.dart';
import 'pdf_generator.dart';

class EnergySldUtils {
  // Enhanced bay actions with full functionality
  static void showBayActions(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
    SldController sldController,
    bool isViewingSavedSld,
    EnergyDataService energyDataService,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => _buildBayActionDialog(
        context,
        bay,
        tapPosition,
        sldController,
        isViewingSavedSld,
        energyDataService,
      ),
    );
  }

  static Widget _buildBayActionDialog(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
    SldController sldController,
    bool isViewingSavedSld,
    EnergyDataService energyDataService,
  ) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    double left = tapPosition.dx;
    double top = tapPosition.dy;

    const dialogWidth = 280.0;
    const dialogHeight = 500.0; // Increased for more options

    // Smart positioning to keep menu on screen
    if (left + dialogWidth > screenSize.width - 20) {
      left = screenSize.width - dialogWidth - 20;
    }
    if (top + dialogHeight > screenSize.height - 20) {
      top = screenSize.height - dialogHeight - 20;
    }
    if (left < 20) left = 20;
    if (top < 100) top = 100;

    return Stack(
      children: [
        // Transparent barrier to close menu
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
        // Positioned menu
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: dialogWidth,
              constraints: const BoxConstraints(
                maxHeight: 600,
              ), // Added constraint
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogHeader(bay, theme, isViewingSavedSld),
                  Flexible(
                    // Added to prevent overflow
                    child: SingleChildScrollView(
                      child: _buildDialogContent(
                        context,
                        bay,
                        theme,
                        sldController,
                        isViewingSavedSld,
                        energyDataService,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildDialogHeader(
    Bay bay,
    ThemeData theme,
    bool isViewingSavedSld,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getBayIcon(bay.bayType),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bay.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${bay.bayType} • ${bay.voltageLevel}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isViewingSavedSld)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                'READ-ONLY',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildDialogContent(
    BuildContext context,
    Bay bay,
    ThemeData theme,
    SldController sldController,
    bool isViewingSavedSld,
    EnergyDataService energyDataService,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isViewingSavedSld) ...[
            // Movement Actions Section
            _buildSectionHeader('Position & Layout'),
            _buildActionItem(
              context: context,
              icon: Icons.open_with,
              title: 'Move Bay',
              subtitle: 'Adjust position on diagram',
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).pop();
                sldController.setSelectedBayForMovement(
                  bay.id,
                  mode: MovementMode.bay,
                );
                SnackBarUtils.showSnackBar(
                  context,
                  'Use arrow keys or drag to move ${bay.name}',
                  // type: SnackBarType.info,
                );
              },
            ),

            _buildActionItem(
              context: context,
              icon: Icons.text_fields,
              title: 'Move Label',
              subtitle: 'Adjust text position',
              color: Colors.green,
              onTap: () {
                Navigator.of(context).pop();
                sldController.setSelectedBayForMovement(
                  bay.id,
                  mode: MovementMode.text,
                );
                SnackBarUtils.showSnackBar(
                  context,
                  'Moving text for ${bay.name}',
                  // type: SnackBarType.info,
                );
              },
            ),

            // Busbar specific actions
            if (bay.bayType.toLowerCase() == 'busbar') ...[
              _buildActionItem(
                context: context,
                icon: Icons.linear_scale,
                title: 'Adjust Length',
                subtitle: 'Modify busbar length',
                color: Colors.indigo,
                onTap: () {
                  Navigator.of(context).pop();
                  sldController.setSelectedBayForMovement(
                    bay.id,
                    mode: MovementMode.busbarLength,
                  );
                  SnackBarUtils.showSnackBar(
                    context,
                    'Use +/- keys to adjust busbar length',
                    // type: SnackBarType.info,
                  );
                },
              ),

              _buildActionItem(
                context: context,
                icon: Icons.settings_input_antenna,
                title: 'Configure Busbar',
                subtitle: 'Manage connected bays',
                color: Colors.purple,
                onTap: () {
                  Navigator.of(context).pop();
                  energyDataService.showBusbarSelectionDialog(
                    context,
                    sldController,
                  );
                },
              ),
            ],

            const Divider(height: 24),

            // Energy & Data Section
            _buildSectionHeader('Energy & Data'),
            _buildActionItem(
              context: context,
              icon: Icons.format_list_numbered,
              title: 'Move Energy Text',
              subtitle: 'Adjust energy readings position',
              color: Colors.orange,
              onTap: () {
                Navigator.of(context).pop();
                sldController.setSelectedBayForMovement(
                  bay.id,
                  mode: MovementMode.energyText,
                );
                SnackBarUtils.showSnackBar(
                  context,
                  'Moving energy readings for ${bay.name}',
                  // type: SnackBarType.info,
                );
              },
            ),

            // Assessment action for non-busbar bays
            if (bay.bayType.toLowerCase() != 'busbar') ...[
              _buildActionItem(
                context: context,
                icon: Icons.assessment,
                title: 'Add Assessment',
                subtitle: 'Create assessment for this bay',
                color: Colors.red,
                onTap: () {
                  Navigator.of(context).pop();
                  _showEnergyAssessmentDialog(
                    context,
                    bay,
                    sldController,
                    energyDataService,
                  );
                },
              ),
            ],

            const Divider(height: 24),

            // Export Actions Section
            _buildSectionHeader('Export'),
            _buildActionItem(
              context: context,
              icon: Icons.picture_as_pdf,
              title: 'Export as PDF',
              subtitle: 'Generate PDF of current bay',
              color: Colors.deepOrange,
              onTap: () async {
                Navigator.of(context).pop();
                await _exportBayAsPdf(context, bay, sldController);
              },
            ),
          ] else ...[
            // Read-only state
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Read-Only Mode',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This is a saved SLD view. Editing is not available.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),
          ],

          // Always available actions
          _buildSectionHeader('Information'),
          _buildActionItem(
            context: context,
            icon: Icons.info_outline,
            title: 'Bay Details',
            subtitle: 'View complete bay information',
            color: Colors.grey,
            onTap: () {
              Navigator.of(context).pop();
              _showBayDetailsDialog(context, bay, sldController);
            },
          ),

          const SizedBox(height: 16),

          // Close Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Section header widget
  static Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(height: 1, width: 50, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  static Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color.withOpacity(0.6),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _getBayIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'busbar':
        return Icons.horizontal_rule;
      case 'transformer':
        return Icons.change_circle;
      case 'line':
        return Icons.timeline;
      case 'feeder':
        return Icons.power;
      default:
        return Icons.electrical_services;
    }
  }

  // Enhanced assessment dialog
  static void _showEnergyAssessmentDialog(
    BuildContext context,
    Bay bay,
    SldController sldController,
    EnergyDataService energyDataService,
  ) {
    showDialog(
      context: context,
      builder: (context) => EnergyAssessmentDialog(
        bay: bay,
        currentUser: energyDataService.currentUser,
        currentEnergyData: sldController.bayEnergyData[bay.id],
        onSaveAssessment: () async {
          // Reload energy data after assessment
          await energyDataService.loadLiveEnergyData(
            DateTime.now().subtract(const Duration(days: 1)),
            DateTime.now(),
            sldController,
          );

          if (context.mounted) {
            SnackBarUtils.showSnackBar(
              context,
              'Assessment saved for ${bay.name}',
              // type: SnackBarType.success,
            );
          }
        },
        latestExistingAssessment: sldController.latestAssessmentsPerBay[bay.id],
      ),
    );
  }

  // Enhanced bay details dialog
  static void _showBayDetailsDialog(
    BuildContext context,
    Bay bay,
    SldController sldController,
  ) {
    final energyData = sldController.bayEnergyData[bay.id];
    final hasEnergyData = energyData != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _getBayIcon(bay.bayType),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(bay.name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Bay Information
              Text(
                'Bay Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Bay ID', bay.id),
              _buildDetailRow('Type', bay.bayType),
              _buildDetailRow('Voltage Level', bay.voltageLevel),
              if (bay.make != null && bay.make!.isNotEmpty)
                _buildDetailRow('Make', bay.make!),
              if (bay.hvBusId != null)
                _buildDetailRow('HV Bus ID', bay.hvBusId!),
              if (bay.lvBusId != null)
                _buildDetailRow('LV Bus ID', bay.lvBusId!),
              _buildDetailRow('Created By', bay.createdBy),
              _buildDetailRow(
                'Created At',
                DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(bay.createdAt.toDate().toLocal()),
              ),

              // Energy Data Section
              if (hasEnergyData) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Energy Data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Import Reading',
                  energyData.importReading.toStringAsFixed(2),
                ),
                _buildDetailRow(
                  'Export Reading',
                  energyData.exportReading.toStringAsFixed(2),
                ),
                _buildDetailRow(
                  'Import Consumed',
                  energyData.adjustedImportConsumed.toStringAsFixed(2),
                ),
                _buildDetailRow(
                  'Export Consumed',
                  energyData.adjustedExportConsumed.toStringAsFixed(2),
                ),
                _buildDetailRow(
                  'Multiplier Factor',
                  energyData.multiplierFactor.toStringAsFixed(2),
                ),
                if (energyData.hasAssessment)
                  _buildDetailRow('Has Assessment', 'Yes', isHighlighted: true),
              ],

              // Position Information
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Position Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              if (bay.xPosition != null)
                _buildDetailRow(
                  'X Position',
                  bay.xPosition!.toStringAsFixed(1),
                ),
              if (bay.yPosition != null)
                _buildDetailRow(
                  'Y Position',
                  bay.yPosition!.toStringAsFixed(1),
                ),
              if (bay.busbarLength != null &&
                  bay.bayType.toLowerCase() == 'busbar')
                _buildDetailRow(
                  'Busbar Length',
                  bay.busbarLength!.toStringAsFixed(1),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isHighlighted ? Colors.orange.shade700 : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? Colors.orange.shade700 : null,
                fontWeight: isHighlighted ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: PDF export functionality
  static Future<void> _exportBayAsPdf(
    BuildContext context,
    Bay bay,
    SldController sldController,
  ) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Generate PDF using the PDFGenerator utility
      await PdfGenerator.generateSldPdf(
        bayRenderDataList: sldController.bayRenderDataList,
        bayConnections: sldController.allConnections,
        baysMap: sldController.baysMap,
        busbarRects: sldController.busbarRects,
        busbarConnectionPoints: sldController.busbarConnectionPoints,
        bayEnergyData: sldController.bayEnergyData,
        busEnergySummary: sldController.busEnergySummary,
        showEnergyReadings: sldController.showEnergyReadings,
        filename:
            'SLD_${bay.name}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
        title: 'Single Line Diagram - ${bay.name}',
        focusedBayId: bay.id, // Highlight the specific bay
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        SnackBarUtils.showSnackBar(
          context,
          'PDF exported successfully for ${bay.name}',
          // type: SnackBarType.success,
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        SnackBarUtils.showSnackBar(
          context,
          'Failed to export PDF: ${e.toString()}',
          // type: SnackBarType.error,
        );
      }
    }
  }

  // NEW: Utility method to check if bay has unsaved changes
  static bool hasPendingChanges(Bay bay, SldController sldController) {
    return sldController.selectedBayForMovementId == bay.id;
  }

  // NEW: Quick action to save changes
  static Future<void> saveChanges(
    BuildContext context,
    SldController sldController,
  ) async {
    try {
      final success = await sldController.saveAllPendingChanges();

      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSnackBar(
            context,
            'Changes saved successfully',
            // type: SnackBarType.success,
          );
        } else {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to save changes',
            // type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error saving changes: ${e.toString()}',
          // type: SnackBarType.error,
        );
      }
    }
  }
}
