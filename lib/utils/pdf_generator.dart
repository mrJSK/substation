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
    print('DEBUG: Starting PDF generation');
    print('DEBUG: SLD image bytes length: ${data.sldImageBytes.length}');

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
    }

    // Build abstract table data
    List<String> abstractTableHeaders = [''];
    for (String voltage in data.uniqueBusVoltages) {
      abstractTableHeaders.add('$voltage BUS');
    }
    abstractTableHeaders.add('ABSTRACT OF S/S');
    abstractTableHeaders.add('TOTAL');
    print('DEBUG: Abstract table headers: $abstractTableHeaders');

    List<List<String>> abstractTableData = [];
    final List<String> rowLabels = [
      'Imp. (MWH)',
      'Exp. (MWH)',
      'Diff. (MWH)',
      '% Loss',
    ];

    // Generate abstract table data (keeping your existing logic)
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

    print('DEBUG: Starting PDF page construction');

    // CRITICAL FIX: Use Page instead of MultiPage to avoid infinite loops
    try {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header section - REMOVE border and shadow
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(12),
                  // REMOVED: decoration with border
                  child: pw.Column(
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
                      pw.SizedBox(height: 4),
                      pw.Text(
                        data.substationName,
                        style: pw.TextStyle(font: regularFont, fontSize: 14),
                      ),
                      pw.Text(
                        'Period: ${data.dateRange}',
                        style: pw.TextStyle(font: regularFont, fontSize: 12),
                      ),
                      pw.Text(
                        'Generated: ${DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 12),

                // SLD Image section - REMOVE border
                if (sldPdfImage != null)
                  pw.Container(
                    width: double.infinity,
                    height: 200,
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Single Line Diagram',
                          style: pw.TextStyle(font: boldFont, fontSize: 14),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Expanded(
                          child: pw.Container(
                            // REMOVED: decoration with border
                            child: pw.Image(
                              sldPdfImage,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  pw.Container(
                    height: 40,
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

                pw.SizedBox(height: 12),

                // Abstract table (constrained)
                pw.Container(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Consolidated Energy Abstract',
                        style: pw.TextStyle(font: boldFont, fontSize: 14),
                      ),
                      pw.SizedBox(height: 8),
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
                        cellPadding: pw.EdgeInsets.all(2),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 12),

                // Assessments section (if space allows)
                if (data.assessmentsForPdf.isNotEmpty)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Assessments for this Period',
                          style: pw.TextStyle(font: boldFont, fontSize: 14),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Table.fromTextArray(
                          context: context,
                          headers: [
                            'Bay Name',
                            'Import Adj.',
                            'Export Adj.',
                            'Reason',
                          ],
                          data: data.assessmentsForPdf.take(5).map((
                            assessmentMap,
                          ) {
                            return [
                              assessmentMap['bayName'] ?? 'N/A',
                              (assessmentMap['importAdjustment'] ?? 0.0)
                                  .toString(),
                              (assessmentMap['exportAdjustment'] ?? 0.0)
                                  .toString(),
                              (assessmentMap['reason'] ?? '')
                                          .toString()
                                          .length >
                                      30
                                  ? (assessmentMap['reason'] ?? '')
                                            .toString()
                                            .substring(0, 30) +
                                        '...'
                                  : (assessmentMap['reason'] ?? '').toString(),
                            ];
                          }).toList(),
                          border: pw.TableBorder.all(width: 0.5),
                          headerStyle: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8,
                          ),
                          cellStyle: pw.TextStyle(
                            font: regularFont,
                            fontSize: 7,
                          ),
                          cellPadding: pw.EdgeInsets.all(2),
                        ),
                      ],
                    ),
                  ),
              ],
            );
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
