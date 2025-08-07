// lib/utils/energy_sld_utils.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../enums/movement_mode.dart';
import '../models/user_model.dart';
import '../models/bay_model.dart';
import '../models/saved_sld_model.dart';
import '../models/assessment_model.dart';
import '../controllers/sld_controller.dart';
import '../services/energy_data_service.dart';
import '../widgets/energy_assessment_dialog.dart';
import '../utils/snackbar_utils.dart';
import '../utils/pdf_generator.dart';

class EnergySldUtils {
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
      barrierColor: Colors.black.withOpacity(0.3),
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
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
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
            const Divider(height: 20),
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
          ] else ...[
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

  static Future<void> saveSld(
    BuildContext context,
    String substationId,
    String substationName,
    AppUser currentUser,
    DateTime startDate,
    DateTime endDate,
    SldController sldController,
    List<Assessment> allAssessmentsForDisplay,
  ) async {
    final TextEditingController sldNameController = TextEditingController();

    final String? sldName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.save_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('Save SLD As...'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sldNameController,
              decoration: const InputDecoration(
                hintText: "Enter SLD name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              autofocus: true,
              maxLength: 50,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (sldNameController.text.trim().isEmpty) {
                SnackBarUtils.showSnackBar(
                  context,
                  'SLD name cannot be empty!',
                  isError: true,
                );
              } else {
                Navigator.pop(context, sldNameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (sldName == null || sldName.isEmpty) return;

    try {
      final currentSldParameters = _buildSldParameters(sldController);
      final assessmentsSummary = _buildAssessmentsSummary(
        allAssessmentsForDisplay,
        sldController,
      );

      final newSavedSld = SavedSld(
        name: sldName,
        substationId: substationId,
        substationName: substationName,
        startDate: Timestamp.fromDate(startDate),
        endDate: Timestamp.fromDate(endDate),
        createdBy: currentUser.uid,
        createdAt: Timestamp.now(),
        sldParameters: currentSldParameters,
        assessmentsSummary: assessmentsSummary,
      );

      await FirebaseFirestore.instance
          .collection('savedSlds')
          .add(newSavedSld.toFirestore());

      if (context.mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'SLD "$sldName" saved successfully!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save SLD: $e',
          isError: true,
        );
      }
    }
  }

  static Map<String, dynamic> _buildSldParameters(SldController sldController) {
    return {
      'bayPositions': {
        for (var renderData in sldController.bayRenderDataList)
          renderData.bay.id: {
            'x': renderData.rect.center.dx,
            'y': renderData.rect.center.dy,
            'textOffsetDx': renderData.textOffset.dx,
            'textOffsetDy': renderData.textOffset.dy,
            'busbarLength': renderData.busbarLength,
            'energyReadingOffsetDx': renderData.energyReadingOffset.dx,
            'energyReadingOffsetDy': renderData.energyReadingOffset.dy,
            'energyReadingFontSize': renderData.energyReadingFontSize,
            'energyReadingIsBold': renderData.energyReadingIsBold,
          },
      },
      'bayEnergyData': {
        for (var entry in sldController.bayEnergyData.entries)
          if (entry.value != null) entry.key: entry.value!.toMap(),
      },
      'busEnergySummary': sldController.busEnergySummary,
      'abstractEnergyData': sldController.abstractEnergyData,
      'aggregatedFeederEnergyData': sldController.aggregatedFeederEnergyData
          .where((e) => e != null)
          .map((e) => e!.toMap())
          .toList(),
    };
  }

  static List<Map<String, dynamic>> _buildAssessmentsSummary(
    List<Assessment> assessments,
    SldController sldController,
  ) {
    return assessments
        .where((assessment) => assessment != null)
        .map(
          (assessment) => {
            ...assessment.toFirestore(),
            'bayName': sldController.baysMap[assessment.bayId]?.name ?? 'N/A',
          },
        )
        .toList();
  }

  static Future<void> shareAsPdf(
    BuildContext context,
    String substationName,
    DateTime startDate,
    DateTime endDate,
    SldController sldController,
    List<Assessment> allAssessmentsForDisplay,
    bool isViewingSavedSld,
    dynamic loadedAssessmentsSummary,
  ) async {
    try {
      SnackBarUtils.showSnackBar(context, 'Generating PDF...');

      // Create date range string
      String dateRange;
      if (startDate.isAtSameMomentAs(endDate)) {
        dateRange = DateFormat('dd-MMM-yyyy').format(startDate);
      } else {
        dateRange =
            '${DateFormat('dd-MMM-yyyy').format(startDate)} to ${DateFormat('dd-MMM-yyyy').format(endDate)}';
      }

      // Capture SLD as image (you might need to implement this)
      Uint8List sldImageBytes = Uint8List(
        0,
      ); // Placeholder - implement SLD capture

      // Get unique bus voltages
      List<String> uniqueBusVoltages = sldController.allBays
          .where((bay) => bay.bayType == 'Busbar')
          .map((bay) => bay.voltageLevel)
          .toSet()
          .toList();

      // Sort voltages by value
      uniqueBusVoltages.sort((a, b) {
        double getVoltage(String v) {
          final regex = RegExp(r'(\d+(\.\d+)?)');
          final match = regex.firstMatch(v);
          return match != null ? double.tryParse(match.group(1)!) ?? 0.0 : 0.0;
        }

        return getVoltage(b).compareTo(getVoltage(a));
      });

      // Prepare assessments data for PDF
      List<Map<String, dynamic>> assessmentsForPdf = allAssessmentsForDisplay
          .map((assessment) {
            Map<String, dynamic> assessmentMap = assessment.toFirestore();
            assessmentMap['bayName'] =
                sldController.baysMap[assessment.bayId]?.name ?? 'Unknown';
            return assessmentMap;
          })
          .toList();

      // Create PdfGeneratorData
      final pdfData = PdfGeneratorData(
        substationName: substationName,
        dateRange: dateRange,
        sldImageBytes: sldImageBytes,
        abstractEnergyData: sldController.abstractEnergyData,
        busEnergySummaryData: sldController.busEnergySummary,
        aggregatedFeederData: sldController.aggregatedFeederEnergyData,
        assessmentsForPdf: assessmentsForPdf,
        uniqueBusVoltages: uniqueBusVoltages,
        allBaysInSubstation: sldController.allBays,
        baysMap: sldController.baysMap,
        uniqueDistributionSubdivisionNames: [], // Add if needed
      );

      // Generate PDF using your existing PdfGenerator
      final pdfBytes = await PdfGenerator.generateEnergyReportPdf(pdfData);

      // Create filename
      final filename =
          'Energy_SLD_${substationName.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';

      // Share PDF using your existing method
      await PdfGenerator.sharePdf(
        pdfBytes,
        filename,
        'Energy SLD Report - $substationName',
      );

      if (context.mounted) {
        // Hide generating message
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        SnackBarUtils.showSnackBar(
          context,
          'PDF generated and shared successfully!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate PDF: $e',
          isError: true,
        );
      }
    }
  }
}

extension on Object {
  toMap() {}
}
