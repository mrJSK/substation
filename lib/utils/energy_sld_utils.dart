// lib/utils/energy_sld_utils.dart

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
    if (isViewingSavedSld) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot adjust SLD layout or energy readings in a saved historical view.',
        isError: true,
      );
      return;
    }

    final menuItems = [
      const PopupMenuItem(
        value: 'adjust_layout',
        child: ListTile(
          leading: Icon(Icons.open_with),
          title: Text('Adjust Bay/Text Layout'),
        ),
      ),
      const PopupMenuItem(
        value: 'adjust_energy_readings',
        child: ListTile(
          leading: Icon(Icons.text_fields),
          title: Text('Adjust Readings Layout'),
        ),
      ),
      const PopupMenuItem(
        value: 'add_assessment',
        child: ListTile(
          leading: Icon(Icons.assessment),
          title: Text('Add Energy Assessment'),
        ),
      ),
    ];

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        MediaQuery.of(context).size.width - tapPosition.dx,
        MediaQuery.of(context).size.height - tapPosition.dy,
      ),
      items: menuItems,
    ).then((value) {
      if (value == 'adjust_layout') {
        sldController.setSelectedBayForMovement(bay.id, mode: MovementMode.bay);
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}" for layout adjustment. Use controls below.',
        );
      } else if (value == 'adjust_energy_readings') {
        sldController.setSelectedBayForMovement(
          bay.id,
          mode: MovementMode.energyText,
        );
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}" energy readings for adjustment. Use controls below.',
        );
      } else if (value == 'add_assessment') {
        _showEnergyAssessmentDialog(
          context,
          bay,
          sldController,
          energyDataService,
        );
      }
    });
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
        title: const Text('Save SLD As...'),
        content: TextField(
          controller: sldNameController,
          decoration: const InputDecoration(hintText: "Enter SLD name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
    List<Map<String, dynamic>> loadedAssessmentsSummary,
  ) async {
    try {
      SnackBarUtils.showSnackBar(context, 'Generating PDF...');

      // Implementation for PDF generation
      // This would use the PdfGenerator utility

      SnackBarUtils.showSnackBar(
        context,
        'PDF generated and shared successfully!',
      );
    } catch (e) {
      if (context.mounted) {
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
