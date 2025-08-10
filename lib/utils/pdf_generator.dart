// lib/utils/pdf_generator.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/bay_model.dart';
import '../models/energy_readings_data.dart';

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
  final double sldBaseLogicalWidth;
  final double sldBaseLogicalHeight;
  final double sldZoom;
  final Offset sldOffset;

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
    required this.sldBaseLogicalWidth,
    required this.sldBaseLogicalHeight,
    required this.sldZoom,
    required this.sldOffset,
  });
}

class PdfGenerator {
  static Future<Uint8List> generateEnergyReportPdf(
    PdfGeneratorData data,
  ) async {
    final pdf = pw.Document();

    // Convert Flutter image to PDF image
    final sldImage = pw.MemoryImage(data.sldImageBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(data),
            pw.SizedBox(height: 20),

            // SLD Image
            _buildSldSection(sldImage, data),
            pw.SizedBox(height: 20),

            // Energy Summary
            _buildEnergySummary(data),
            pw.SizedBox(height: 20),

            // Bus Energy Details
            _buildBusEnergyDetails(data),
            pw.SizedBox(height: 20),

            // Assessments
            if (data.assessmentsForPdf.isNotEmpty) ...[
              _buildAssessmentsSection(data),
              pw.SizedBox(height: 20),
            ],

            // Footer
            _buildFooter(),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(PdfGeneratorData data) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Energy SLD Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Substation: ${data.substationName}',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.Text(
                'Period: ${data.dateRange}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Generated on:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                DateTime.now().toString().split('.')[0],
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSldSection(
    pw.ImageProvider sldImage,
    PdfGeneratorData data,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Single Line Diagram',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          height: 300,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Center(child: pw.Image(sldImage, fit: pw.BoxFit.contain)),
        ),
      ],
    );
  }

  static pw.Widget _buildEnergySummary(PdfGeneratorData data) {
    final abstract = data.abstractEnergyData;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Energy Summary',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Metric', isHeader: true),
                _buildTableCell('Value', isHeader: true),
                _buildTableCell('Unit', isHeader: true),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Total Import'),
                _buildTableCell(
                  '${abstract['totalImp']?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildTableCell('kWh'),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Total Export'),
                _buildTableCell(
                  '${abstract['totalExp']?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildTableCell('kWh'),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Net Difference'),
                _buildTableCell(
                  '${abstract['difference']?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildTableCell('kWh'),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Loss Percentage'),
                _buildTableCell(
                  '${abstract['lossPercentage']?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildTableCell('%'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildBusEnergyDetails(PdfGeneratorData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bus Energy Breakdown',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Bus Name', isHeader: true),
                _buildTableCell('Voltage Level', isHeader: true),
                _buildTableCell('Import (kWh)', isHeader: true),
                _buildTableCell('Export (kWh)', isHeader: true),
              ],
            ),
            ...data.busEnergySummaryData.entries.map((entry) {
              final busId = entry.key;
              final energyData = entry.value;
              final bay = data.baysMap[busId];

              return pw.TableRow(
                children: [
                  _buildTableCell(bay?.name ?? 'Unknown'),
                  _buildTableCell(bay?.voltageLevel ?? 'N/A'),
                  _buildTableCell(
                    '${energyData['totalImp']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  _buildTableCell(
                    '${energyData['totalExp']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAssessmentsSection(PdfGeneratorData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Energy Assessments',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        ...data.assessmentsForPdf.map((assessment) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${assessment['assessmentType']} - ${assessment['bayName']}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  assessment['comments'] ?? 'No comments',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      child: pw.Text(
        'This report was automatically generated by the Energy Management System.',
        style: const pw.TextStyle(fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static Future<void> sharePdf(
    Uint8List pdfBytes,
    String filename,
    String subject,
  ) async {
    try {
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');

      // Write PDF bytes to file
      await file.writeAsBytes(pdfBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject,
        text: 'Energy SLD Report',
      );
    } catch (e) {
      throw Exception('Failed to share PDF: $e');
    }
  }
}
