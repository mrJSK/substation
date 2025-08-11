// lib/utils/pdf_generator.dart

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/bay_model.dart';
import '../models/bay_connection_model.dart';
import '../models/energy_readings_data.dart';
import '../painters/single_line_diagram_painter.dart';

class PdfGeneratorData {
  final String substationName;
  final String dateRange;
  final Uint8List sldImageBytes;
  final Map abstractEnergyData;
  final Map<String, Map<String, double>> busEnergySummaryData;
  final List aggregatedFeederData;
  final List<Map<String, dynamic>> assessmentsForPdf;
  final List uniqueBusVoltages;
  final List allBaysInSubstation;
  final Map<String, Bay> baysMap;
  final List uniqueDistributionSubdivisionNames;
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
  // NEW: Generate SLD PDF method
  static Future<void> generateSldPdf({
    required List<BayRenderData> bayRenderDataList,
    required List<BayConnection> bayConnections,
    required Map<String, Bay> baysMap,
    required Map<String, Rect> busbarRects,
    required Map<String, Map<String, Offset>> busbarConnectionPoints,
    required Map<String, BayEnergyData> bayEnergyData,
    required Map<String, Map<String, double>> busEnergySummary,
    required bool showEnergyReadings,
    required String filename,
    required String title,
    String? focusedBayId,
  }) async {
    try {
      // Create a custom painter for PDF generation
      final sldImageBytes = await _captureSldAsImage(
        bayRenderDataList: bayRenderDataList,
        bayConnections: bayConnections,
        baysMap: baysMap,
        busbarRects: busbarRects,
        busbarConnectionPoints: busbarConnectionPoints,
        bayEnergyData: bayEnergyData,
        busEnergySummary: busEnergySummary,
        showEnergyReadings: showEnergyReadings,
        focusedBayId: focusedBayId,
      );

      final pdf = pw.Document();
      final sldImage = pw.MemoryImage(sldImageBytes);

      pdf.addPage(
        pw.MultiPage(
          pageFormat:
              PdfPageFormat.a4.landscape, // Landscape for better SLD viewing
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header
              _buildSldPdfHeader(title),
              pw.SizedBox(height: 20),

              // SLD Image
              _buildSldImageSection(sldImage, title),
              pw.SizedBox(height: 20),

              // Bay Information Table
              if (focusedBayId != null && baysMap[focusedBayId] != null)
                _buildFocusedBayInfo(
                  baysMap[focusedBayId]!,
                  bayEnergyData[focusedBayId],
                ),

              // Energy Summary (if energy readings are shown)
              if (showEnergyReadings && bayEnergyData.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _buildEnergyDataSection(
                  bayEnergyData,
                  busEnergySummary,
                  baysMap,
                ),
              ],

              // Bay List
              pw.SizedBox(height: 20),
              _buildBayListSection(bayRenderDataList),
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

      // Save and share the PDF
      await _savePdf(pdf.save(), filename, title);
    } catch (e) {
      throw Exception('Failed to generate SLD PDF: $e');
    }
  }

  // Capture SLD as image for PDF
  static Future<Uint8List> _captureSldAsImage({
    required List<BayRenderData> bayRenderDataList,
    required List<BayConnection> bayConnections,
    required Map<String, Bay> baysMap,
    required Map<String, Rect> busbarRects,
    required Map<String, Map<String, Offset>> busbarConnectionPoints,
    required Map<String, BayEnergyData> bayEnergyData,
    required Map<String, Map<String, double>> busEnergySummary,
    required bool showEnergyReadings,
    String? focusedBayId,
  }) async {
    // Calculate content bounds
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var renderData in bayRenderDataList) {
      minX = minX.isInfinite
          ? renderData.rect.left
          : (renderData.rect.left < minX ? renderData.rect.left : minX);
      minY = minY.isInfinite
          ? renderData.rect.top
          : (renderData.rect.top < minY ? renderData.rect.top : minY);
      maxX = maxX.isInfinite
          ? renderData.rect.right
          : (renderData.rect.right > maxX ? renderData.rect.right : maxX);
      maxY = maxY.isInfinite
          ? renderData.rect.bottom
          : (renderData.rect.bottom > maxY ? renderData.rect.bottom : maxY);
    }

    const padding = 100.0;
    final width = (maxX - minX) + 2 * padding;
    final height = (maxY - minY) + 2 * padding;

    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Create the painter
    final painter = SingleLineDiagramPainter(
      bayRenderDataList: bayRenderDataList,
      bayConnections: bayConnections,
      baysMap: baysMap,
      createDummyBayRenderData: () => BayRenderData(
        bay: Bay(
          id: 'dummy',
          name: '',
          substationId: '',
          voltageLevel: '',
          bayType: '',
          createdBy: '',
          createdAt: Timestamp.now(),
        ),
        rect: Rect.zero,
        center: Offset.zero,
        topCenter: Offset.zero,
        bottomCenter: Offset.zero,
        leftCenter: Offset.zero,
        rightCenter: Offset.zero,
        equipmentInstances: const [],
        textOffset: Offset.zero,
        busbarLength: 0.0,
        energyReadingOffset: Offset.zero,
        energyReadingFontSize: 9.0,
        energyReadingIsBold: false,
      ),
      busbarRects: busbarRects,
      busbarConnectionPoints: busbarConnectionPoints,
      debugDrawHitboxes: false,
      selectedBayForMovementId: focusedBayId, // Highlight focused bay
      bayEnergyData: bayEnergyData,
      busEnergySummary: busEnergySummary,
      showEnergyReadings: showEnergyReadings,
      contentBounds: Size(maxX - minX, maxY - minY),
      originOffsetForPdf: Offset(-minX + padding, -minY + padding),
      defaultBayColor: Colors.black,
      defaultLineFeederColor: Colors.black,
      transformerColor: Colors.blue,
      connectionLineColor: Colors.black,
    );

    // Paint the SLD
    painter.paint(canvas, Size(width, height));

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  static pw.Widget _buildSldPdfHeader(String title) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Generated from Energy Management System',
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

  static pw.Widget _buildSldImageSection(
    pw.ImageProvider sldImage,
    String title,
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
          height: 400, // Increased height for landscape
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Center(child: pw.Image(sldImage, fit: pw.BoxFit.contain)),
        ),
      ],
    );
  }

  static pw.Widget _buildFocusedBayInfo(Bay bay, BayEnergyData? energyData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bay Information - ${bay.name}',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Property', isHeader: true),
                _buildTableCell('Value', isHeader: true),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Bay Type'),
                _buildTableCell(bay.bayType),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Voltage Level'),
                _buildTableCell(bay.voltageLevel),
              ],
            ),
            if (bay.make != null && bay.make!.isNotEmpty)
              pw.TableRow(
                children: [_buildTableCell('Make'), _buildTableCell(bay.make!)],
              ),
            if (energyData != null) ...[
              pw.TableRow(
                children: [
                  _buildTableCell('Import Reading'),
                  _buildTableCell(
                    '${energyData.importReading.toStringAsFixed(2)} kWh',
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('Export Reading'),
                  _buildTableCell(
                    '${energyData.exportReading.toStringAsFixed(2)} kWh',
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('Net Consumption'),
                  _buildTableCell(
                    '${energyData.adjustedImportConsumed.toStringAsFixed(2)} kWh',
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildEnergyDataSection(
    Map<String, BayEnergyData> bayEnergyData,
    Map<String, Map<String, double>> busEnergySummary,
    Map<String, Bay> baysMap,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Energy Data Summary',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Bay Name', isHeader: true),
                _buildTableCell('Type', isHeader: true),
                _buildTableCell('Import (kWh)', isHeader: true),
                _buildTableCell('Export (kWh)', isHeader: true),
              ],
            ),
            ...bayEnergyData.entries.take(10).map((entry) {
              final bay = baysMap[entry.key];
              final energyData = entry.value;
              return pw.TableRow(
                children: [
                  _buildTableCell(bay?.name ?? 'Unknown'),
                  _buildTableCell(bay?.bayType ?? 'N/A'),
                  _buildTableCell(energyData.importReading.toStringAsFixed(2)),
                  _buildTableCell(energyData.exportReading.toStringAsFixed(2)),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildBayListSection(List<BayRenderData> bayRenderDataList) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bay List',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Bay Name', isHeader: true),
                _buildTableCell('Type', isHeader: true),
                _buildTableCell('Voltage Level', isHeader: true),
                _buildTableCell('Make', isHeader: true),
              ],
            ),
            ...bayRenderDataList.take(20).map((renderData) {
              return pw.TableRow(
                children: [
                  _buildTableCell(renderData.bay.name),
                  _buildTableCell(renderData.bay.bayType),
                  _buildTableCell(renderData.bay.voltageLevel),
                  _buildTableCell(renderData.bay.make ?? 'N/A'),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  // Existing energy report generation method
  static Future<Uint8List> generateEnergyReportPdf(
    PdfGeneratorData data,
  ) async {
    final pdf = pw.Document();
    final sldImage = pw.MemoryImage(data.sldImageBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            _buildHeader(data),
            pw.SizedBox(height: 20),
            _buildSldSection(sldImage, data),
            pw.SizedBox(height: 20),
            _buildEnergySummary(data),
            pw.SizedBox(height: 20),
            _buildBusEnergyDetails(data),
            pw.SizedBox(height: 20),
            if (data.assessmentsForPdf.isNotEmpty) ...[
              _buildAssessmentsSection(data),
              pw.SizedBox(height: 20),
            ],
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

  // Helper method to save and share PDF
  static Future<void> _savePdf(
    Future<Uint8List> pdfBytesFuture,
    String filename,
    String subject,
  ) async {
    final pdfBytes = await pdfBytesFuture;
    await sharePdf(pdfBytes, '$filename.pdf', subject);
  }

  // Existing helper methods
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
          height: 600,
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
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(pdfBytes);

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
