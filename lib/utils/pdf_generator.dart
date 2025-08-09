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
import '../models/energy_readings_data.dart';
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart';

/// A data class to hold all necessary information for PDF generation
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
  final List<String> uniqueDistributionSubdivisionNames;

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
    required this.uniqueDistributionSubdivisionNames,
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

    // Load fonts to prevent Unicode issues
    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      regularFont = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
    } catch (e) {
      // Fallback to defaults if font loading fails
    }

    pw.MemoryImage? sldPdfImage;
    if (data.sldImageBytes.isNotEmpty) {
      try {
        sldPdfImage = pw.MemoryImage(data.sldImageBytes);
      } catch (e) {
        // Handle image creation error
      }
    }

    // Build abstract table headers
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

    // Generate abstract table data (restored exact loop from previous working version)
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
            final imp = busSummary['totalImp'] ?? 0.0;
            final exp = busSummary['totalExp'] ?? 0.0;
            final diff = busSummary['difference'] ?? 0.0;

            totalForThisBusVoltageImp += imp;
            totalForThisBusVoltageExp += exp;
            totalForThisBusVoltageDiff += diff;
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
            final lossPercentage =
                ((totalForThisBusVoltageDiff / totalForThisBusVoltageImp) *
                100);
            lossValue = lossPercentage.toStringAsFixed(2);
          }
          row.add(lossValue);
        }
      }

      // Add Abstract of S/S data
      if (rowLabels[i].contains('Imp.')) {
        final abstractImp = data.abstractEnergyData['totalImp'] ?? 0.0;
        row.add(abstractImp.toStringAsFixed(2));
        rowTotalSummable += abstractImp;
        overallTotalImpForLossCalc += abstractImp;
      } else if (rowLabels[i].contains('Exp.')) {
        final abstractExp = data.abstractEnergyData['totalExp'] ?? 0.0;
        row.add(abstractExp.toStringAsFixed(2));
        rowTotalSummable += abstractExp;
      } else if (rowLabels[i].contains('Diff.')) {
        final abstractDiff = data.abstractEnergyData['difference'] ?? 0.0;
        row.add(abstractDiff.toStringAsFixed(2));
        rowTotalSummable += abstractDiff;
        overallTotalDiffForLossCalc += abstractDiff;
      } else if (rowLabels[i].contains('Loss')) {
        final abstractLoss = data.abstractEnergyData['lossPercentage'] ?? 0.0;
        row.add(abstractLoss.toStringAsFixed(2));
      }

      // Add TOTAL column
      if (rowLabels[i].contains('Loss')) {
        String overallTotalLossPercentage = 'N/A';
        if (overallTotalImpForLossCalc > 0) {
          final totalLossPercentage =
              ((overallTotalDiffForLossCalc / overallTotalImpForLossCalc) *
              100);
          overallTotalLossPercentage = totalLossPercentage.toStringAsFixed(2);
        }
        row.add(overallTotalLossPercentage);
      } else {
        row.add(rowTotalSummable.toStringAsFixed(2));
      }

      abstractTableData.add(row);
    }

    // Build PDF page with restored multi-page handling
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
                  font: boldFont,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                data.substationName,
                style: pw.TextStyle(font: regularFont, fontSize: 14),
              ),
              pw.Text(
                'Period: ${data.dateRange}',
                style: pw.TextStyle(font: regularFont, fontSize: 12),
              ),
              pw.Divider(),
            ],
          );
        },
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];

          // Add SLD Image - restored centering and scaling
          if (sldPdfImage != null) {
            widgets.addAll([
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Single Line Diagram',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      width: double.infinity,
                      height: 400,
                      child: pw.Center(
                        child: pw.Image(
                          sldPdfImage,
                          fit: pw.BoxFit.contain,
                          alignment: pw.Alignment.center,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 30),
                  ],
                ),
              ),
            ]);
          } else {
            widgets.add(
              pw.Container(
                height: 400,
                child: pw.Center(
                  child: pw.Text(
                    'SLD Diagram could not be captured.',
                    style: pw.TextStyle(
                      font: regularFont,
                      color: PdfColors.red,
                    ),
                  ),
                ),
              ),
            );
          }

          // Add Consolidated Energy Abstract Table (restored full structure)
          widgets.addAll([
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
                font: boldFont,
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: pw.TextStyle(font: regularFont, fontSize: 8),
              cellAlignment: pw.Alignment.center,
              cellPadding: pw.EdgeInsets.all(3),
              columnWidths: {
                0: pw.FlexColumnWidth(1.2),
                for (int i = 0; i < data.uniqueBusVoltages.length; i++)
                  (i + 1): pw.FlexColumnWidth(1.0),
                (data.uniqueBusVoltages.length + 1): pw.FlexColumnWidth(1.2),
                (data.uniqueBusVoltages.length + 2): pw.FlexColumnWidth(1.2),
              },
            ),
            pw.SizedBox(height: 20),
          ]);

          // Add Feeder Data Section (restored aggregation)
          widgets.addAll([
            pw.Header(
              level: 0,
              text: 'Feeder Energy Supplied by Distribution Hierarchy',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
          ]);

          if (data.aggregatedFeederData.isNotEmpty) {
            widgets.add(
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
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: pw.TextStyle(font: regularFont, fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: pw.EdgeInsets.all(4),
              ),
            );
          } else {
            widgets.add(pw.Text('No aggregated feeder energy data available.'));
          }

          widgets.add(pw.SizedBox(height: 20));

          // Add Assessments Section (restored full table)
          widgets.addAll([
            pw.Header(
              level: 0,
              text: 'Assessments for this Period',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
          ]);

          if (data.assessmentsForPdf.isNotEmpty) {
            try {
              widgets.add(
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
                    try {
                      final Assessment assessment = Assessment.fromMap(
                        assessmentMap,
                      );
                      final bayName = assessmentMap['bayName'] ?? 'N/A';
                      final importAdj =
                          assessment.importAdjustment?.toStringAsFixed(2) ??
                          'N/A';
                      final exportAdj =
                          assessment.exportAdjustment?.toStringAsFixed(2) ??
                          'N/A';
                      final reason = assessment.reason;
                      final timestamp = DateFormat(
                        'dd-MMM-yyyy HH:mm',
                      ).format(assessment.assessmentTimestamp.toDate());

                      return <String>[
                        bayName,
                        importAdj,
                        exportAdj,
                        reason,
                        timestamp,
                      ];
                    } catch (e) {
                      return <String>[
                        'Error',
                        'Error',
                        'Error',
                        'Error',
                        'Error',
                      ];
                    }
                  }).toList(),
                  border: pw.TableBorder.all(width: 0.5),
                  headerStyle: pw.TextStyle(
                    font: boldFont,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(font: regularFont, fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: pw.EdgeInsets.all(4),
                  columnWidths: {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(3),
                    4: pw.FlexColumnWidth(2),
                  },
                ),
              );
            } catch (e) {
              widgets.add(pw.Text('Error generating assessments table.'));
            }
          } else {
            widgets.add(pw.Text('No assessments were made for this period.'));
          }

          return widgets;
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
    try {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      final fileExists = await file.exists();
      if (fileExists) {
        await Share.shareXFiles([XFile(file.path)], subject: subject);
      } else {
        throw Exception('Failed to create temporary PDF file');
      }
    } catch (e) {
      throw e;
    }
  }
}
