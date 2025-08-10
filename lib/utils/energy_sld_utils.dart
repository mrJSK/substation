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
import '../utils/pdf_generator.dart';

class EnergySldUtils {
  // Menu-only functionality from the original EnergySldUtils
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
    const dialogHeight = 400.0;

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
                  _buildDialogContent(
                    context,
                    bay,
                    theme,
                    sldController,
                    isViewingSavedSld,
                    energyDataService,
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
            // Move Bay Action
            _buildActionItem(
              context: context,
              icon: Icons.open_with,
              title: 'Move Bay',
              subtitle: 'Adjust the position on the diagram',
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).pop();
                sldController.setSelectedBayForMovement(
                  bay.id,
                  mode: MovementMode.bay,
                );
              },
            ),

            // const Divider(height: 20),

            // // Edit Text Action
            // _buildActionItem(
            //   context: context,
            //   icon: Icons.text_fields,
            //   title: 'Edit Text',
            //   subtitle: 'Modify bay label',
            //   color: Colors.green,
            //   onTap: () {
            //     Navigator.of(context).pop();
            //     sldController.setSelectedBayForMovement(
            //       bay.id,
            //       mode: MovementMode.text,
            //     );
            //   },
            // ),

            // const Divider(height: 20),

            // // Energy Readings Action
            // _buildActionItem(
            //   context: context,
            //   icon: Icons.format_list_numbered,
            //   title: 'Energy Readings',
            //   subtitle: 'View detailed energy data',
            //   color: Colors.orange,
            //   onTap: () {
            //     Navigator.of(context).pop();
            //     sldController.setSelectedBayForMovement(
            //       bay.id,
            //       mode: MovementMode.energyText,
            //     );
            //   },
            // ),
            // if (bay.bayType.toLowerCase() != 'busbar') ...[
            //   const Divider(height: 20),

            //   // Assessment Action
            //   _buildActionItem(
            //     context: context,
            //     icon: Icons.assessment,
            //     title: 'Add Assessment',
            //     subtitle: 'Create assessment for this bay',
            //     color: Colors.red,
            //     onTap: () {
            //       Navigator.of(context).pop();
            //       _showEnergyAssessmentDialog(
            //         context,
            //         bay,
            //         sldController,
            //         energyDataService,
            //       );
            //     },
            //   ),
            // ],
            if (bay.bayType.toLowerCase() == 'busbar') ...[
              const Divider(height: 20),

              // Busbar Configuration Action
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
          ],

          const SizedBox(height: 16),

          // Bay Details Action (always available)
          _buildActionItem(
            context: context,
            icon: Icons.info_outline,
            title: 'Bay Details',
            subtitle: 'View bay properties',
            color: Colors.grey,
            onTap: () {
              Navigator.of(context).pop();
              _showBayDetailsDialog(context, bay);
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

  // Supporting dialog methods for the menu
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
        onSaveAssessment: () => energyDataService.loadLiveEnergyData(
          DateTime.now().subtract(const Duration(days: 1)),
          DateTime.now(),
          sldController,
        ),
        latestExistingAssessment: sldController.latestAssessmentsPerBay[bay.id],
      ),
    );
  }

  static void _showBayDetailsDialog(BuildContext context, Bay bay) {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Bay ID', bay.id),
            _buildDetailRow('Type', bay.bayType),
            _buildDetailRow('Voltage Level', bay.voltageLevel),
            if (bay.make != null && bay.make!.isNotEmpty)
              _buildDetailRow('Make', bay.make!),
            _buildDetailRow('Created By', bay.createdBy),
            _buildDetailRow(
              'Created At',
              bay.createdAt.toDate().toLocal().toString().split('.')[0],
            ),
          ],
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

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
