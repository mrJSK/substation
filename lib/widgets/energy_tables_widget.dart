// lib/widgets/energy_tables_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/sld_controller.dart';
import '../models/assessment_model.dart';

class EnergyTablesWidget extends StatelessWidget {
  final bool isViewingSavedSld;
  final List<Map<String, dynamic>> loadedAssessmentsSummary;
  final List<Assessment> allAssessmentsForDisplay;

  const EnergyTablesWidget({
    super.key,
    required this.isViewingSavedSld,
    required this.loadedAssessmentsSummary,
    required this.allAssessmentsForDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final sldController = Provider.of<SldController>(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        // ← FIX: Make the entire content scrollable
        child: Column(
          children: [
            _buildConsolidatedEnergyTable(context, sldController),
            const SizedBox(height: 16),
            _buildAssessmentsTable(context, sldController),
          ],
        ),
      ),
    );
  }

  Widget _buildConsolidatedEnergyTable(
    BuildContext context,
    SldController sldController,
  ) {
    return Container(
      // ← FIX: Remove fixed height to prevent overflow
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consolidated Energy Abstract',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // ← FIX: Wrap in SingleChildScrollView with intrinsic height
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateColor.resolveWith(
                (states) =>
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              columns: _buildAbstractTableHeaders(sldController),
              rows: _buildConsolidatedEnergyTableRows(sldController),
              columnSpacing: 24,
              horizontalMargin: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentsTable(
    BuildContext context,
    SldController sldController,
  ) {
    if (isViewingSavedSld && loadedAssessmentsSummary.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          'No assessments were made for this period in the saved SLD.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!isViewingSavedSld && allAssessmentsForDisplay.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      // ← FIX: Remove fixed height, let content determine height
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isViewingSavedSld
                ? 'Assessments for this Period'
                : 'Recent Assessment Notes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // ← FIX: Constrain height but allow scrolling
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 150, // Reasonable max height
            ),
            child: isViewingSavedSld
                ? _buildSavedAssessmentsTable(context, sldController)
                : _buildRecentAssessmentsList(context, sldController),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAssessmentsTable(
    BuildContext context,
    SldController sldController,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical, // ← FIX: Allow vertical scrolling
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // ← FIX: Allow horizontal scrolling
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith(
            (states) => Colors.orange.shade50,
          ),
          columns: const [
            DataColumn(label: Text('Bay Name')),
            DataColumn(label: Text('Import Adj.')),
            DataColumn(label: Text('Export Adj.')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Timestamp')),
          ],
          rows: loadedAssessmentsSummary.map((assessmentMap) {
            final assessment = Assessment.fromMap(assessmentMap);
            final assessedBayName = assessmentMap['bayName'] ?? 'N/A';

            return DataRow(
              cells: [
                DataCell(Text(assessedBayName)),
                DataCell(
                  Text(
                    assessment.importAdjustment?.toStringAsFixed(2) ?? 'N/A',
                  ),
                ),
                DataCell(
                  Text(
                    assessment.exportAdjustment?.toStringAsFixed(2) ?? 'N/A',
                  ),
                ),
                DataCell(Text(assessment.reason)),
                DataCell(
                  Text(
                    DateFormat(
                      'dd-MMM-yyyy HH:mm',
                    ).format(assessment.assessmentTimestamp.toDate()),
                  ),
                ),
              ],
            );
          }).toList(),
          columnSpacing: 24,
          horizontalMargin: 16,
        ),
      ),
    );
  }

  Widget _buildRecentAssessmentsList(
    BuildContext context,
    SldController sldController,
  ) {
    return ListView.separated(
      shrinkWrap: true, // ← FIX: Allow ListView to take only needed space
      physics: const ClampingScrollPhysics(), // ← FIX: Better scroll physics
      itemCount: allAssessmentsForDisplay.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final assessment = allAssessmentsForDisplay[index];
        final assessedBay = sldController.baysMap[assessment.bayId];

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '• ${assessedBay?.name ?? 'Unknown Bay'} on ${DateFormat('dd-MMM-yyyy HH:mm').format(assessment.assessmentTimestamp.toDate())}: ${assessment.reason}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }

  // ... rest of your existing methods remain the same
  List<DataColumn> _buildAbstractTableHeaders(SldController sldController) {
    List<String> headers = [''];

    final uniqueBusVoltages =
        sldController.allBays
            .where((bay) => bay.bayType == 'Busbar')
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
          );

    for (String voltage in uniqueBusVoltages) {
      headers.add('$voltage BUS');
    }

    headers.addAll(['ABSTRACT OF S/S', 'TOTAL']);

    return headers
        .map(
          (header) => DataColumn(
            label: Text(
              header,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        )
        .toList();
  }

  List<DataRow> _buildConsolidatedEnergyTableRows(SldController sldController) {
    final rowLabels = [
      'Import (MWH)',
      'Export (MWH)',
      'Difference (MWH)',
      'Loss (%)',
    ];

    final uniqueBusVoltages =
        sldController.allBays
            .where((bay) => bay.bayType == 'Busbar')
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
          );

    return rowLabels.asMap().entries.map((entry) {
      final index = entry.key;
      final label = entry.value;

      List<DataCell> cells = [DataCell(Text(label))];
      double rowTotal = 0.0;

      // Add bus voltage columns
      for (String voltage in uniqueBusVoltages) {
        final busbarsOfVoltage = sldController.allBays.where(
          (bay) => bay.bayType == 'Busbar' && bay.voltageLevel == voltage,
        );

        double totalForVoltage = 0.0;

        for (var busbar in busbarsOfVoltage) {
          final busSummary = sldController.busEnergySummary[busbar.id];
          if (busSummary != null) {
            switch (index) {
              case 0: // Import
                totalForVoltage += busSummary['totalImp'] ?? 0.0;
                break;
              case 1: // Export
                totalForVoltage += busSummary['totalExp'] ?? 0.0;
                break;
              case 2: // Difference
                totalForVoltage += busSummary['difference'] ?? 0.0;
                break;
              case 3: // Loss
                if ((busSummary['totalImp'] ?? 0.0) > 0) {
                  totalForVoltage =
                      ((busSummary['difference'] ?? 0.0) /
                          (busSummary['totalImp'] ?? 1.0)) *
                      100;
                }
                break;
            }
          }
        }

        cells.add(
          DataCell(
            Text(
              index == 3
                  ? '${totalForVoltage.toStringAsFixed(2)}%'
                  : totalForVoltage.toStringAsFixed(2),
            ),
          ),
        );

        if (index != 3) rowTotal += totalForVoltage;
      }

      // Add abstract column
      final abstractValue = index == 3
          ? sldController.abstractEnergyData['lossPercentage'] ?? 0.0
          : _getAbstractValue(index, sldController);

      cells.add(
        DataCell(
          Text(
            index == 3
                ? '${abstractValue.toStringAsFixed(2)}%'
                : abstractValue.toStringAsFixed(2),
          ),
        ),
      );

      if (index != 3) rowTotal += abstractValue;

      // Add total column
      cells.add(
        DataCell(Text(index == 3 ? 'N/A' : rowTotal.toStringAsFixed(2))),
      );

      return DataRow(cells: cells);
    }).toList();
  }

  double _getAbstractValue(int index, SldController sldController) {
    switch (index) {
      case 0:
        return sldController.abstractEnergyData['totalImp'] ?? 0.0;
      case 1:
        return sldController.abstractEnergyData['totalExp'] ?? 0.0;
      case 2:
        return sldController.abstractEnergyData['difference'] ?? 0.0;
      default:
        return 0.0;
    }
  }

  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }
}
