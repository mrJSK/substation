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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final sldController = Provider.of<SldController>(context);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.2)
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: SingleChildScrollView(
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consolidated Energy Abstract',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Theme(
              data: theme.copyWith(
                dataTableTheme: DataTableThemeData(
                  headingRowColor: MaterialStateColor.resolveWith(
                    (states) => theme.colorScheme.primary.withOpacity(0.1),
                  ),
                  dataRowColor: MaterialStateColor.resolveWith(
                    (states) =>
                        isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                  ),
                  headingTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  dataTextStyle: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              child: DataTable(
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => theme.colorScheme.primary.withOpacity(0.1),
                ),
                columns: _buildAbstractTableHeaders(sldController, isDarkMode),
                rows: _buildConsolidatedEnergyTableRows(
                  sldController,
                  isDarkMode,
                ),
                columnSpacing: 24,
                horizontalMargin: 16,
              ),
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (isViewingSavedSld && loadedAssessmentsSummary.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          'No assessments were made for this period in the saved SLD.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: isDarkMode
                ? Colors.white.withOpacity(0.6)
                : Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!isViewingSavedSld && allAssessmentsForDisplay.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
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
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Theme(
          data: theme.copyWith(
            dataTableTheme: DataTableThemeData(
              headingRowColor: MaterialStateColor.resolveWith(
                (states) => isDarkMode
                    ? Colors.orange.shade800!.withOpacity(0.3)
                    : Colors.orange.shade50,
              ),
              dataRowColor: MaterialStateColor.resolveWith(
                (states) => isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              ),
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              dataTextStyle: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          child: DataTable(
            headingRowColor: MaterialStateColor.resolveWith(
              (states) => isDarkMode
                  ? Colors.orange.shade800!.withOpacity(0.3)
                  : Colors.orange.shade50,
            ),
            columns: [
              DataColumn(
                label: Text(
                  'Bay Name',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Import Adj.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Export Adj.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Reason',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Timestamp',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
            rows: loadedAssessmentsSummary.map((assessmentMap) {
              final assessment = Assessment.fromMap(assessmentMap);
              final assessedBayName = assessmentMap['bayName'] ?? 'N/A';
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      assessedBayName,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      assessment.importAdjustment?.toStringAsFixed(2) ?? 'N/A',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      assessment.exportAdjustment?.toStringAsFixed(2) ?? 'N/A',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      assessment.reason,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      DateFormat(
                        'dd-MMM-yyyy HH:mm',
                      ).format(assessment.assessmentTimestamp.toDate()),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
            columnSpacing: 24,
            horizontalMargin: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAssessmentsList(
    BuildContext context,
    SldController sldController,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: allAssessmentsForDisplay.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final assessment = allAssessmentsForDisplay[index];
        final assessedBay = sldController.baysMap[assessment.bayId];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '• ${assessedBay?.name ?? 'Unknown Bay'} on ${DateFormat('dd-MMM-yyyy HH:mm').format(assessment.assessmentTimestamp.toDate())}: ${assessment.reason}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        );
      },
    );
  }

  List<DataColumn> _buildAbstractTableHeaders(
    SldController sldController,
    bool isDarkMode,
  ) {
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

    // Removed 'TOTAL' from headers - only add ABSTRACT OF S/S
    headers.add('ABSTRACT OF S/S');

    return headers
        .map(
          (header) => DataColumn(
            label: Text(
              header,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        )
        .toList();
  }

  List<DataRow> _buildConsolidatedEnergyTableRows(
    SldController sldController,
    bool isDarkMode,
  ) {
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

      List<DataCell> cells = [
        DataCell(
          Text(
            label,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
      ];

      // Add bus voltage columns with proper difference and loss% calculations
      for (String voltage in uniqueBusVoltages) {
        final busbarsOfVoltage = sldController.allBays.where(
          (bay) => bay.bayType == 'Busbar' && bay.voltageLevel == voltage,
        );

        double totalForVoltage = 0.0;
        double totalImportForVoltage = 0.0;
        double totalExportForVoltage = 0.0;

        // First, calculate total import and export for this voltage level
        for (var busbar in busbarsOfVoltage) {
          final busSummary = sldController.busEnergySummary[busbar.id];
          if (busSummary != null) {
            totalImportForVoltage += busSummary['totalImp'] ?? 0.0;
            totalExportForVoltage += busSummary['totalExp'] ?? 0.0;
          }
        }

        // Calculate values based on row type
        switch (index) {
          case 0: // Import
            totalForVoltage = totalImportForVoltage;
            break;
          case 1: // Export
            totalForVoltage = totalExportForVoltage;
            break;
          case 2: // Difference
            totalForVoltage = totalImportForVoltage - totalExportForVoltage;
            break;
          case 3: // Loss %
            if (totalImportForVoltage > 0) {
              totalForVoltage =
                  ((totalImportForVoltage - totalExportForVoltage) /
                      totalImportForVoltage) *
                  100;
            } else {
              totalForVoltage = 0.0;
            }
            break;
        }

        cells.add(
          DataCell(
            Text(
              index == 3
                  ? '${totalForVoltage.toStringAsFixed(2)}%'
                  : totalForVoltage.toStringAsFixed(2),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
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
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
      );

      // Removed TOTAL column - no longer adding it to cells

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
