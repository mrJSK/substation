import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart' show TextDirection;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/bay_model.dart';
import '../models/assessment_model.dart';
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart';

/// A data class to hold all necessary information for PDF generation. (Remains same)
class PdfGeneratorData {
  final String substationName;
  final String dateRange;
  final Uint8List sldImageBytes;
  final Map<String, dynamic> abstractEnergyData;
  final Map<String, Map<String, double>> busEnergySummaryData;
  final List<AggregatedFeederEnergyData> aggregatedFeederData;
  final List<Map<String, dynamic>> assessmentsForPdf;
  final List<String> uniqueBusVoltages;
  final List<Bay> allBaysInSubstation;
  final Map<String, Bay> baysMap;

  PdfGeneratorData({
    required this.substationName,
    required this.dateRange,
    required this.sldImageBytes,
    required this.abstractEnergyData,
    required this.busEnergySummaryData,
    required this.aggregatedFeederData,
    required this.assessmentsForPdf,
    required this.uniqueBusVoltages,
    required this.allBaysInSubstation,
    required this.baysMap,
    required List<String> uniqueDistributionSubdivisionNames,
  });
}

class PdfGenerator {
  static double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  static Future<Uint8List> generateEnergyReportPdf(
    PdfGeneratorData data,
  ) async {
    final pdf = pw.Document();

    pw.MemoryImage? sldPdfImage;
    if (data.sldImageBytes.isNotEmpty) {
      sldPdfImage = pw.MemoryImage(data.sldImageBytes);
    }

    List<String> abstractTableHeaders = [''];
    for (String voltage in data.uniqueBusVoltages) {
      abstractTableHeaders.add('$voltage BUS');
    }
    abstractTableHeaders.add('ABSTRACT OF S/S');
    abstractTableHeaders.add('TOTAL');

    List<List<String>> abstractTableData = [];

    final List<String> rowLabels = [
      'Imp. (MWH)',
      'Exp. (MWH)',
      'Diff. (MWH)',
      '% Loss',
    ];

    for (int i = 0; i < rowLabels.length; i++) {
      List<String> row = [rowLabels[i]];
      double rowTotalSummable = 0.0;
      double overallTotalImpForLossCalc = 0.0;
      double overallTotalDiffForLossCalc = 0.0;

      for (String voltage in data.uniqueBusVoltages) {
        final busbarsOfThisVoltage = data.allBaysInSubstation.where(
          (bay) => bay.bayType == 'Busbar' && bay.voltageLevel == voltage,
        );
        double totalForThisBusVoltageImp = 0.0;
        double totalForThisBusVoltageExp = 0.0;
        double totalForThisBusVoltageDiff = 0.0;

        for (var busbar in busbarsOfThisVoltage) {
          final busSummary = data.busEnergySummaryData[busbar.id];
          if (busSummary != null) {
            totalForThisBusVoltageImp += busSummary['totalImp'] ?? 0.0;
            totalForThisBusVoltageExp += busSummary['totalExp'] ?? 0.0;
            totalForThisBusVoltageDiff += busSummary['difference'] ?? 0.0;
          }
        }

        if (rowLabels[i].contains('Imp.')) {
          row.add(totalForThisBusVoltageImp.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageImp;
          overallTotalImpForLossCalc += totalForThisBusVoltageImp;
        } else if (rowLabels[i].contains('Exp.')) {
          row.add(totalForThisBusVoltageExp.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageExp;
        } else if (rowLabels[i].contains('Diff.')) {
          row.add(totalForThisBusVoltageDiff.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageDiff;
          overallTotalDiffForLossCalc += totalForThisBusVoltageDiff;
        } else if (rowLabels[i].contains('Loss')) {
          String lossValue = 'N/A';
          if (totalForThisBusVoltageImp > 0) {
            lossValue =
                ((totalForThisBusVoltageDiff / totalForThisBusVoltageImp) * 100)
                    .toStringAsFixed(2);
          }
          row.add(lossValue);
        }
      }

      // Add Abstract of S/S data
      if (rowLabels[i].contains('Imp.')) {
        row.add(
          (data.abstractEnergyData['totalImp'] ?? 0.0).toStringAsFixed(2),
        );
        rowTotalSummable += (data.abstractEnergyData['totalImp'] ?? 0.0);
        overallTotalImpForLossCalc +=
            (data.abstractEnergyData['totalImp'] ?? 0.0);
      } else if (rowLabels[i].contains('Exp.')) {
        row.add(
          (data.abstractEnergyData['totalExp'] ?? 0.0).toStringAsFixed(2),
        );
        rowTotalSummable += (data.abstractEnergyData['totalExp'] ?? 0.0);
      } else if (rowLabels[i].contains('Diff.')) {
        row.add(
          (data.abstractEnergyData['difference'] ?? 0.0).toStringAsFixed(2),
        );
        rowTotalSummable += (data.abstractEnergyData['difference'] ?? 0.0);
        overallTotalDiffForLossCalc +=
            (data.abstractEnergyData['difference'] ?? 0.0);
      } else if (rowLabels[i].contains('Loss')) {
        row.add(
          (data.abstractEnergyData['lossPercentage'] ?? 0.0).toStringAsFixed(2),
        );
      }

      // Add TOTAL column
      if (rowLabels[i].contains('Loss')) {
        String overallTotalLossPercentage = 'N/A';
        if (overallTotalImpForLossCalc > 0) {
          overallTotalLossPercentage =
              ((overallTotalDiffForLossCalc / overallTotalImpForLossCalc) * 100)
                  .toStringAsFixed(2);
        }
        row.add(overallTotalLossPercentage);
      } else {
        row.add(rowTotalSummable.toStringAsFixed(2));
      }

      abstractTableData.add(row);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginBottom: 1.5 * PdfPageFormat.cm,
          marginTop: 1.5 * PdfPageFormat.cm,
          marginLeft: 1.5 * PdfPageFormat.cm,
          marginRight: 1.5 * PdfPageFormat.cm,
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Substation Energy Account Report',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(data.substationName, style: pw.TextStyle(fontSize: 14)),
              pw.Text(
                'Period: ${data.dateRange}',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Divider(),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            if (sldPdfImage != null)
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Single Line Diagram',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Image(
                      sldPdfImage,
                      fit: pw.BoxFit.contain,
                      width: PdfPageFormat.a4.width - (3 * PdfPageFormat.cm),
                    ),
                    pw.SizedBox(height: 30),
                  ],
                ),
              )
            else
              pw.Text(
                'SLD Diagram could not be captured.',
                style: pw.TextStyle(color: PdfColors.red),
              ),
            pw.Header(
              level: 0,
              text: 'Consolidated Energy Abstract',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            pw.Table.fromTextArray(
              context: context,
              headers: abstractTableHeaders,
              data: abstractTableData,
              border: pw.TableBorder.all(width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.all(3),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                for (int i = 0; i < data.uniqueBusVoltages.length; i++)
                  (i + 1).toInt(): const pw.FlexColumnWidth(1.0),
                (data.uniqueBusVoltages.length + 1).toInt():
                    const pw.FlexColumnWidth(1.2),
                (data.uniqueBusVoltages.length + 2).toInt():
                    const pw.FlexColumnWidth(1.2),
              },
            ),
            pw.SizedBox(height: 20),
            pw.Header(
              level: 0,
              text: 'Feeder Energy Supplied by Distribution Hierarchy',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            if (data.aggregatedFeederData.isNotEmpty)
              pw.Table.fromTextArray(
                context: context,
                headers: <String>[
                  'D-Zone',
                  'D-Circle',
                  'D-Division',
                  'D-Subdivision',
                  'Import (MWH)',
                  'Export (MWH)',
                ],
                data: data.aggregatedFeederData.map((d) {
                  return <String>[
                    d.zoneName,
                    d.circleName,
                    d.divisionName,
                    d.distributionSubdivisionName,
                    d.importedEnergy.toStringAsFixed(2),
                    d.exportedEnergy.toStringAsFixed(2),
                  ];
                }).toList(),
                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(4),
              )
            else
              pw.Text('No aggregated feeder energy data available.'),
            pw.SizedBox(height: 20),
            pw.Header(
              level: 0,
              text: 'Assessments for this Period',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            if (data.assessmentsForPdf.isNotEmpty)
              pw.Table.fromTextArray(
                context: context,
                headers: <String>[
                  'Bay Name',
                  'Import Adj.',
                  'Export Adj.',
                  'Reason',
                  'Timestamp',
                ],
                data: data.assessmentsForPdf.map((assessmentMap) {
                  final Assessment assessment = Assessment.fromMap(
                    assessmentMap,
                  );
                  return <String>[
                    assessmentMap['bayName'] ?? 'N/A',
                    assessment.importAdjustment?.toStringAsFixed(2) ?? 'N/A',
                    assessment.exportAdjustment?.toStringAsFixed(2) ?? 'N/A',
                    assessment.reason,
                    DateFormat(
                      'dd-MMM-yyyy HH:mm',
                    ).format(assessment.assessmentTimestamp.toDate()),
                  ];
                }).toList(),
                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(4),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(3),
                  4: const pw.FlexColumnWidth(2),
                },
              )
            else
              pw.Text('No assessments were made for this period.'),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static Future<void> sharePdf(
    Uint8List pdfBytes,
    String filename,
    String subject,
  ) async {
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$filename');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }
}
