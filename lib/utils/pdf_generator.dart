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
    print('DEBUG: Getting voltage level value for: $voltageLevel');
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      final value = double.tryParse(match.group(1)!) ?? 0.0;
      print('DEBUG: Extracted voltage value: $value');
      return value;
    }
    print('DEBUG: No voltage value found, returning 0.0');
    return 0.0;
  }

  static Future<Uint8List> generateEnergyReportPdf(
    PdfGeneratorData data,
  ) async {
    print('DEBUG: Starting PDF generation with exact placement');
    print('DEBUG: Substation name: ${data.substationName}');
    print('DEBUG: Date range: ${data.dateRange}');
    print('DEBUG: SLD image bytes length: ${data.sldImageBytes.length}');
    print('DEBUG: Unique bus voltages: ${data.uniqueBusVoltages}');
    print('DEBUG: Number of bays: ${data.allBaysInSubstation.length}');
    print('DEBUG: Number of assessments: ${data.assessmentsForPdf.length}');
    print(
      'DEBUG: Number of aggregated feeder data: ${data.aggregatedFeederData.length}',
    );

    final pdf = pw.Document();

    // Load fonts to prevent Unicode issues
    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      regularFont = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
      print('DEBUG: Fonts loaded successfully');
    } catch (e) {
      print('DEBUG: Could not load fonts, using defaults: $e');
    }

    pw.MemoryImage? sldPdfImage;
    if (data.sldImageBytes.isNotEmpty) {
      try {
        sldPdfImage = pw.MemoryImage(data.sldImageBytes);
        print('DEBUG: SLD image successfully created from bytes');
      } catch (e) {
        print('DEBUG ERROR: Failed to create SLD image: $e');
      }
    } else {
      print('DEBUG WARNING: SLD image bytes are empty');
    }

    // Build abstract table headers exactly as in your working code
    List<String> abstractTableHeaders = [''];
    for (String voltage in data.uniqueBusVoltages) {
      abstractTableHeaders.add('$voltage BUS');
    }
    abstractTableHeaders.add('ABSTRACT OF S/S');
    abstractTableHeaders.add('TOTAL');
    print('DEBUG: Abstract table headers: $abstractTableHeaders');

    List<List<String>> abstractTableData = [];
    print('DEBUG: Starting abstract table data generation');

    final List<String> rowLabels = [
      'Imp. (MWH)',
      'Exp. (MWH)',
      'Diff. (MWH)',
      '% Loss',
    ];

    // Generate abstract table data exactly as in your working code
    for (int i = 0; i < rowLabels.length; i++) {
      print('DEBUG: Processing row ${i + 1}/4: ${rowLabels[i]}');
      List<String> row = [rowLabels[i]];
      double rowTotalSummable = 0.0;
      double overallTotalImpForLossCalc = 0.0;
      double overallTotalDiffForLossCalc = 0.0;

      for (String voltage in data.uniqueBusVoltages) {
        print('DEBUG: Processing voltage level: $voltage');

        final busbarsOfThisVoltage = data.allBaysInSubstation.where(
          (bay) => bay.bayType == 'Busbar' && bay.voltageLevel == voltage,
        );
        print(
          'DEBUG: Found ${busbarsOfThisVoltage.length} busbars for voltage $voltage',
        );

        double totalForThisBusVoltageImp = 0.0;
        double totalForThisBusVoltageExp = 0.0;
        double totalForThisBusVoltageDiff = 0.0;

        for (var busbar in busbarsOfThisVoltage) {
          print('DEBUG: Processing busbar: ${busbar.name} (ID: ${busbar.id})');
          final busSummary = data.busEnergySummaryData[busbar.id];
          if (busSummary != null) {
            final imp = busSummary['totalImp'] ?? 0.0;
            final exp = busSummary['totalExp'] ?? 0.0;
            final diff = busSummary['difference'] ?? 0.0;
            print(
              'DEBUG: Busbar ${busbar.name} - Imp: $imp, Exp: $exp, Diff: $diff',
            );

            totalForThisBusVoltageImp += imp;
            totalForThisBusVoltageExp += exp;
            totalForThisBusVoltageDiff += diff;
          } else {
            print(
              'DEBUG WARNING: No bus summary data found for busbar ${busbar.id}',
            );
          }
        }

        print(
          'DEBUG: Total for $voltage - Imp: $totalForThisBusVoltageImp, Exp: $totalForThisBusVoltageExp, Diff: $totalForThisBusVoltageDiff',
        );

        if (rowLabels[i].contains('Imp.')) {
          row.add(totalForThisBusVoltageImp.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageImp;
          overallTotalImpForLossCalc += totalForThisBusVoltageImp;
          print(
            'DEBUG: Added import value: ${totalForThisBusVoltageImp.toStringAsFixed(2)}',
          );
        } else if (rowLabels[i].contains('Exp.')) {
          row.add(totalForThisBusVoltageExp.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageExp;
          print(
            'DEBUG: Added export value: ${totalForThisBusVoltageExp.toStringAsFixed(2)}',
          );
        } else if (rowLabels[i].contains('Diff.')) {
          row.add(totalForThisBusVoltageDiff.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageDiff;
          overallTotalDiffForLossCalc += totalForThisBusVoltageDiff;
          print(
            'DEBUG: Added difference value: ${totalForThisBusVoltageDiff.toStringAsFixed(2)}',
          );
        } else if (rowLabels[i].contains('Loss')) {
          String lossValue = 'N/A';
          if (totalForThisBusVoltageImp > 0) {
            final lossPercentage =
                ((totalForThisBusVoltageDiff / totalForThisBusVoltageImp) *
                100);
            lossValue = lossPercentage.toStringAsFixed(2);
            print('DEBUG: Calculated loss percentage: $lossPercentage%');
          } else {
            print('DEBUG: Cannot calculate loss percentage - import is 0');
          }
          row.add(lossValue);
          print('DEBUG: Added loss value: $lossValue');
        }
      }

      // Add Abstract of S/S data
      print('DEBUG: Adding Abstract of S/S data for row: ${rowLabels[i]}');
      if (rowLabels[i].contains('Imp.')) {
        final abstractImp = data.abstractEnergyData['totalImp'] ?? 0.0;
        row.add(abstractImp.toStringAsFixed(2));
        rowTotalSummable += abstractImp;
        overallTotalImpForLossCalc += abstractImp;
        print('DEBUG: Abstract import: $abstractImp');
      } else if (rowLabels[i].contains('Exp.')) {
        final abstractExp = data.abstractEnergyData['totalExp'] ?? 0.0;
        row.add(abstractExp.toStringAsFixed(2));
        rowTotalSummable += abstractExp;
        print('DEBUG: Abstract export: $abstractExp');
      } else if (rowLabels[i].contains('Diff.')) {
        final abstractDiff = data.abstractEnergyData['difference'] ?? 0.0;
        row.add(abstractDiff.toStringAsFixed(2));
        rowTotalSummable += abstractDiff;
        overallTotalDiffForLossCalc += abstractDiff;
        print('DEBUG: Abstract difference: $abstractDiff');
      } else if (rowLabels[i].contains('Loss')) {
        final abstractLoss = data.abstractEnergyData['lossPercentage'] ?? 0.0;
        row.add(abstractLoss.toStringAsFixed(2));
        print('DEBUG: Abstract loss percentage: $abstractLoss%');
      }

      // Add TOTAL column
      if (rowLabels[i].contains('Loss')) {
        String overallTotalLossPercentage = 'N/A';
        if (overallTotalImpForLossCalc > 0) {
          final totalLossPercentage =
              ((overallTotalDiffForLossCalc / overallTotalImpForLossCalc) *
              100);
          overallTotalLossPercentage = totalLossPercentage.toStringAsFixed(2);
          print('DEBUG: Overall total loss percentage: $totalLossPercentage%');
        } else {
          print(
            'DEBUG: Cannot calculate overall loss percentage - total import is 0',
          );
        }
        row.add(overallTotalLossPercentage);
      } else {
        row.add(rowTotalSummable.toStringAsFixed(2));
        print('DEBUG: Row total summable: $rowTotalSummable');
      }

      abstractTableData.add(row);
      print('DEBUG: Completed row ${i + 1}: $row');
    }

    print(
      'DEBUG: Abstract table data generation completed. Rows: ${abstractTableData.length}',
    );

    // Build PDF page with EXACT layout from your working code
    print('DEBUG: Starting PDF page construction');
    try {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginBottom: 1.5 * PdfPageFormat.cm,
            marginTop: 1.5 * PdfPageFormat.cm,
            marginLeft: 1.5 * PdfPageFormat.cm,
            marginRight: 1.5 * PdfPageFormat.cm,
          ),
          header: (pw.Context context) {
            print('DEBUG: Building PDF header');
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
            print('DEBUG: Building PDF content');
            List<pw.Widget> widgets = [];

            // Add SLD Image - CENTERED AND PROPERLY SCALED
            if (sldPdfImage != null) {
              print('DEBUG: Adding SLD image to PDF');
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
                        height: 400, // Fixed height for consistent layout
                        child: pw.Center(
                          child: pw.Image(
                            sldPdfImage,
                            fit: pw.BoxFit.contain, // Auto-scale and center
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
              print(
                'DEBUG WARNING: Adding error message for missing SLD image',
              );
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

            // Add Consolidated Energy Abstract Table
            print('DEBUG: Adding consolidated energy abstract table');
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

            // Add Feeder Data Section
            print('DEBUG: Adding feeder energy data section');
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
              print(
                'DEBUG: Adding ${data.aggregatedFeederData.length} feeder data entries',
              );
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
                    print(
                      'DEBUG: Adding feeder data: ${d.distributionSubdivisionName} - Import: ${d.importedEnergy}, Export: ${d.exportedEnergy}',
                    );
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
              print('DEBUG WARNING: No aggregated feeder data available');
              widgets.add(
                pw.Text('No aggregated feeder energy data available.'),
              );
            }

            widgets.add(pw.SizedBox(height: 20));

            // Add Assessments Section
            print('DEBUG: Adding assessments section');
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
              print(
                'DEBUG: Adding ${data.assessmentsForPdf.length} assessment entries',
              );
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

                        print(
                          'DEBUG: Adding assessment: $bayName - Import: $importAdj, Export: $exportAdj',
                        );

                        return <String>[
                          bayName,
                          importAdj,
                          exportAdj,
                          reason,
                          timestamp,
                        ];
                      } catch (e) {
                        print('DEBUG ERROR: Failed to process assessment: $e');
                        print('DEBUG: Assessment map: $assessmentMap');
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
                print('DEBUG ERROR: Failed to create assessments table: $e');
                widgets.add(pw.Text('Error generating assessments table.'));
              }
            } else {
              print('DEBUG: No assessments available for this period');
              widgets.add(pw.Text('No assessments were made for this period.'));
            }

            print(
              'DEBUG: PDF content widgets completed. Total widgets: ${widgets.length}',
            );
            return widgets;
          },
        ),
      );

      print('DEBUG: PDF page added successfully');
    } catch (e) {
      print('DEBUG ERROR: Failed to create PDF page: $e');
      throw e;
    }

    try {
      final pdfBytes = await pdf.save();
      print(
        'DEBUG: PDF generation completed successfully. Size: ${pdfBytes.length} bytes',
      );
      return pdfBytes;
    } catch (e) {
      print('DEBUG ERROR: Failed to save PDF: $e');
      throw e;
    }
  }

  static Future<void> sharePdf(
    Uint8List pdfBytes,
    String filename,
    String subject,
  ) async {
    print('DEBUG: Starting PDF sharing process');
    print('DEBUG: PDF size: ${pdfBytes.length} bytes');
    print('DEBUG: Filename: $filename');
    print('DEBUG: Subject: $subject');

    try {
      final output = await getTemporaryDirectory();
      print('DEBUG: Temporary directory: ${output.path}');

      final file = File('${output.path}/$filename');
      print('DEBUG: Full file path: ${file.path}');

      await file.writeAsBytes(pdfBytes);
      print('DEBUG: PDF file written successfully');

      final fileExists = await file.exists();
      if (fileExists) {
        final fileSize = await file.length();
        print('DEBUG: Confirmed file exists with size: $fileSize bytes');
      } else {
        print('DEBUG ERROR: File was not created successfully');
        throw Exception('Failed to create temporary PDF file');
      }

      await Share.shareXFiles([XFile(file.path)], subject: subject);
      print('DEBUG: PDF sharing completed successfully');
    } catch (e) {
      print('DEBUG ERROR: PDF sharing failed: $e');
      throw e;
    }
  }
}
