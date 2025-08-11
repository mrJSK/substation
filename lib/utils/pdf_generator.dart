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
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              _buildSldPdfHeader(title),
              pw.SizedBox(height: 20),
              _buildSldImageSection(sldImage, title),
              pw.SizedBox(height: 20),
              if (focusedBayId != null && baysMap[focusedBayId] != null)
                _buildFocusedBayInfo(
                  baysMap[focusedBayId]!,
                  bayEnergyData[focusedBayId],
                ),
              if (showEnergyReadings && bayEnergyData.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _buildEnergyDataSection(
                  bayEnergyData,
                  busEnergySummary,
                  baysMap,
                ),
              ],
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
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            );
          },
        ),
      );

      await _savePdf(pdf.save(), filename, title);
    } catch (e) {
      throw Exception('Failed to generate SLD PDF: $e');
    }
  }

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

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

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
      selectedBayForMovementId: focusedBayId,
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

    painter.paint(canvas, Size(width, height));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  static Future<Uint8List> generateEnergyReportPdf(
    PdfGeneratorData data,
  ) async {
    final pdf = pw.Document();
    final sldImage = pw.MemoryImage(data.sldImageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          final double totalPageHeight = PdfPageFormat.a4.height - 40;
          final double headerHeight =
              totalPageHeight * 0.08; // Increased slightly
          final double sldHeight =
              totalPageHeight * 0.70; // Reduced to fit table
          final double tableHeaderHeight =
              totalPageHeight * 0.04; // Space for table header
          final double tableHeight =
              totalPageHeight * 0.18; // Increased for better visibility

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: headerHeight, child: _buildHeader(data)),

              pw.Container(
                height: sldHeight,
                child: _buildSldSection(sldImage, data),
              ),

              pw.Container(
                // height: tableHeaderHeight,
                child: _buildTableHeader(),
              ),

              pw.Container(
                // height: tableHeight,
                child: _buildConsolidatedEnergyTable(data),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Updated header with voltage levels and complete title
  static pw.Widget _buildHeader(PdfGeneratorData data) {
    // Get the highest voltage level from the busbars
    String highestVoltage = '';
    if (data.busEnergySummaryData.isNotEmpty) {
      final voltages =
          data.busEnergySummaryData.entries
              .map((entry) {
                final bay = data.baysMap[entry.key];
                return _extractVoltageValue(bay?.voltageLevel ?? '0');
              })
              .where((voltage) => voltage > 0)
              .toList()
            ..sort((a, b) => b.compareTo(a));

      if (voltages.isNotEmpty) {
        highestVoltage = '${voltages.first.toInt()}kV';
      }
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 12,
      ), // Reduced padding
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left side: Main title with substation and voltage
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Energy Account',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$highestVoltage ${data.substationName}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.normal,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
          // Right side: Period and generation date
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Period: ${data.dateRange}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.normal,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${DateTime.now().toString().split('.')[0].split(' ')[0]}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.normal,
                  color: PdfColors.grey700,
                ),
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
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Center(child: pw.Image(sldImage, fit: pw.BoxFit.contain)),
      ),
    );
  }

  // New table header section
  static pw.Widget _buildTableHeader() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        'Energy Abstract Summary',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Updated table with better sizing for complete visibility
  static pw.Widget _buildConsolidatedEnergyTable(PdfGeneratorData data) {
    final abstract = data.abstractEnergyData;

    // Sort busbars by voltage level (highest to lowest)
    final busbars = data.busEnergySummaryData.entries.toList()
      ..sort((a, b) {
        final bayA = data.baysMap[a.key];
        final bayB = data.baysMap[b.key];

        final voltageA = _extractVoltageValue(bayA?.voltageLevel ?? '0');
        final voltageB = _extractVoltageValue(bayB?.voltageLevel ?? '0');

        return voltageB.compareTo(voltageA);
      });

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6), // Reduced padding
        child: pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: _buildColumnWidths(busbars.length),
          children: [
            // Header row with busbar names (sorted by voltage)
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableHeaderCell('Metric'),
                ...busbars.map((entry) {
                  final bay = data.baysMap[entry.key];
                  return _buildTableHeaderCell(
                    '${bay?.voltageLevel ?? 'Unknown'} BUS',
                  );
                }).toList(),
                _buildTableHeaderCell('TOTAL'),
              ],
            ),

            // Import (MWh) row
            pw.TableRow(
              children: [
                _buildTableDataCell('Import (MWh)', isBold: true),
                ...busbars.map((entry) {
                  final energyData = entry.value;
                  final importMWh = (energyData['totalImp'] ?? 0.0) / 1000;
                  return _buildTableDataCell(importMWh.toStringAsFixed(2));
                }).toList(),
                _buildTableDataCell(
                  '${((abstract['totalImp'] ?? 0.0) / 1000).toStringAsFixed(2)}',
                  isBold: true,
                ),
              ],
            ),

            // Export (MWh) row
            pw.TableRow(
              children: [
                _buildTableDataCell('Export (MWh)', isBold: true),
                ...busbars.map((entry) {
                  final energyData = entry.value;
                  final exportMWh = (energyData['totalExp'] ?? 0.0) / 1000;
                  return _buildTableDataCell(exportMWh.toStringAsFixed(2));
                }).toList(),
                _buildTableDataCell(
                  '${((abstract['totalExp'] ?? 0.0) / 1000).toStringAsFixed(2)}',
                  isBold: true,
                ),
              ],
            ),

            // Difference (MWh) row
            pw.TableRow(
              children: [
                _buildTableDataCell('Difference (MWh)', isBold: true),
                ...busbars.map((entry) {
                  final energyData = entry.value;
                  final importMWh = (energyData['totalImp'] ?? 0.0) / 1000;
                  final exportMWh = (energyData['totalExp'] ?? 0.0) / 1000;
                  final difference = importMWh - exportMWh;
                  return _buildTableDataCell(difference.toStringAsFixed(2));
                }).toList(),
                _buildTableDataCell(
                  '${((abstract['difference'] ?? 0.0) / 1000).toStringAsFixed(2)}',
                  isBold: true,
                ),
              ],
            ),

            // Loss (%) row
            pw.TableRow(
              children: [
                _buildTableDataCell('Loss (%)', isBold: true),
                ...busbars.map((entry) {
                  final energyData = entry.value;
                  final importMWh = (energyData['totalImp'] ?? 0.0) / 1000;
                  final exportMWh = (energyData['totalExp'] ?? 0.0) / 1000;
                  final difference = importMWh - exportMWh;
                  final lossPercentage = importMWh > 0
                      ? ((difference / importMWh) * 100)
                      : 0.0;
                  return _buildTableDataCell(
                    '${lossPercentage.toStringAsFixed(2)}%',
                  );
                }).toList(),
                _buildTableDataCell(
                  '${(abstract['lossPercentage'] ?? 0.0).toStringAsFixed(2)}%',
                  isBold: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to extract numeric voltage value for sorting
  static double _extractVoltageValue(String voltageLevel) {
    final cleanVoltage = voltageLevel
        .toUpperCase()
        .replaceAll('KV', '')
        .replaceAll(' ', '')
        .trim();

    try {
      return double.parse(cleanVoltage);
    } catch (e) {
      return 0.0;
    }
  }

  // Helper method to create dynamic column widths
  static Map<int, pw.TableColumnWidth> _buildColumnWidths(int busbarCount) {
    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FlexColumnWidth(1.8), // Metric column - slightly smaller
    };

    for (int i = 1; i <= busbarCount; i++) {
      columnWidths[i] = const pw.FlexColumnWidth(1.2); // Bus columns - smaller
    }

    columnWidths[busbarCount + 1] = const pw.FlexColumnWidth(
      1.2,
    ); // Total column - smaller

    return columnWidths;
  }

  // Professional table styling for headers
  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 6,
      ), // Reduced padding
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9, // Reduced font size
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Professional table styling for data cells
  static pw.Widget _buildTableDataCell(String text, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 4,
      ), // Reduced padding
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8, // Reduced font size
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // static pw.Widget _buildTableHeader(String text) {
  //   return pw.Container(
  //     padding: const pw.EdgeInsets.all(10),
  //     child: pw.Text(
  //       text,
  //       style: pw.TextStyle(
  //         fontSize: 10,
  //         fontWeight: pw.FontWeight.bold,
  //         color: PdfColors.black,
  //       ),
  //       textAlign: pw.TextAlign.center,
  //     ),
  //   );
  // }

  static pw.Widget _buildTableCell(String text, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.TableRow _buildEnergyTableRow(
    String metric,
    String value,
    String unit,
    PdfColor backgroundColor,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: backgroundColor),
      children: [
        _buildModernTableCell(metric, isMetric: true),
        _buildModernTableCell(value, isValue: true),
        _buildModernTableCell(unit),
      ],
    );
  }

  static pw.Widget _buildModernTableCell(
    String text, {
    bool isHeader = false,
    bool isMetric = false,
    bool isValue = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader
              ? pw.FontWeight.bold
              : isValue
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildSldPdfHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColors.blue600, PdfColors.blue800],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(12),
      ),
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
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Energy Management System',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  DateTime.now().toString().split('.')[0].split(' ')[0],
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey800,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSldImageSection(
    pw.ImageProvider sldImage,
    String title,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Text(
              'Single Line Diagram',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Container(
            height: 400,
            padding: const pw.EdgeInsets.all(16),
            child: pw.Center(child: pw.Image(sldImage, fit: pw.BoxFit.contain)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFocusedBayInfo(Bay bay, BayEnergyData? energyData) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Text(
              'Bay Information - ${bay.name}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 1,
                ),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildModernTableCell('Property', isHeader: true),
                    _buildModernTableCell('Value', isHeader: true),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildModernTableCell('Bay Type'),
                    _buildModernTableCell(bay.bayType),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildModernTableCell('Voltage Level'),
                    _buildModernTableCell(bay.voltageLevel),
                  ],
                ),
                if (bay.make != null && bay.make!.isNotEmpty)
                  pw.TableRow(
                    children: [
                      _buildModernTableCell('Make'),
                      _buildModernTableCell(bay.make!),
                    ],
                  ),
                if (energyData != null) ...[
                  pw.TableRow(
                    children: [
                      _buildModernTableCell('Import Reading'),
                      _buildModernTableCell(
                        '${energyData.importReading.toStringAsFixed(2)} kWh',
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildModernTableCell('Export Reading'),
                      _buildModernTableCell(
                        '${energyData.exportReading.toStringAsFixed(2)} kWh',
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildModernTableCell('Net Consumption'),
                      _buildModernTableCell(
                        '${energyData.adjustedImportConsumed.toStringAsFixed(2)} kWh',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEnergyDataSection(
    Map<String, BayEnergyData> bayEnergyData,
    Map<String, Map<String, double>> busEnergySummary,
    Map<String, Bay> baysMap,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Text(
              'Energy Data Summary',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 1,
                ),
                verticalInside: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 1,
                ),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildModernTableCell('Bay Name', isHeader: true),
                    _buildModernTableCell('Type', isHeader: true),
                    _buildModernTableCell('Import (kWh)', isHeader: true),
                    _buildModernTableCell('Export (kWh)', isHeader: true),
                  ],
                ),
                ...bayEnergyData.entries.take(10).map((entry) {
                  final bay = baysMap[entry.key];
                  final energyData = entry.value;
                  return pw.TableRow(
                    children: [
                      _buildModernTableCell(bay?.name ?? 'Unknown'),
                      _buildModernTableCell(bay?.bayType ?? 'N/A'),
                      _buildModernTableCell(
                        energyData.importReading.toStringAsFixed(2),
                        isValue: true,
                      ),
                      _buildModernTableCell(
                        energyData.exportReading.toStringAsFixed(2),
                        isValue: true,
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBayListSection(List<BayRenderData> bayRenderDataList) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Text(
              'Bay List',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 1,
                ),
                verticalInside: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 1,
                ),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildModernTableCell('Bay Name', isHeader: true),
                    _buildModernTableCell('Type', isHeader: true),
                    _buildModernTableCell('Voltage Level', isHeader: true),
                    _buildModernTableCell('Make', isHeader: true),
                  ],
                ),
                ...bayRenderDataList.take(20).map((renderData) {
                  return pw.TableRow(
                    children: [
                      _buildModernTableCell(renderData.bay.name),
                      _buildModernTableCell(renderData.bay.bayType),
                      _buildModernTableCell(renderData.bay.voltageLevel),
                      _buildModernTableCell(renderData.bay.make ?? 'N/A'),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
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
                _buildBasicTableCell('Metric', isHeader: true),
                _buildBasicTableCell('Value', isHeader: true),
                _buildBasicTableCell('Unit', isHeader: true),
              ],
            ),
            pw.TableRow(
              children: [
                _buildBasicTableCell('Total Import'),
                _buildBasicTableCell(
                  '${abstract['totalImp']?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildBasicTableCell('kWh'),
              ],
            ),
            pw.TableRow(
              children: [
                _buildBasicTableCell('Total Export'),
                _buildBasicTableCell(
                  '${abstract['totalExp']?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildBasicTableCell('kWh'),
              ],
            ),
            pw.TableRow(
              children: [
                _buildBasicTableCell('Net Difference'),
                _buildBasicTableCell(
                  '${abstract['difference']?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildBasicTableCell('kWh'),
              ],
            ),
            pw.TableRow(
              children: [
                _buildBasicTableCell('Loss Percentage'),
                _buildBasicTableCell(
                  '${abstract['lossPercentage']?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildBasicTableCell('%'),
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
                _buildBasicTableCell('Bus Name', isHeader: true),
                _buildBasicTableCell('Voltage Level', isHeader: true),
                _buildBasicTableCell('Import (kWh)', isHeader: true),
                _buildBasicTableCell('Export (kWh)', isHeader: true),
              ],
            ),
            ...data.busEnergySummaryData.entries.map((entry) {
              final busId = entry.key;
              final energyData = entry.value;
              final bay = data.baysMap[busId];
              return pw.TableRow(
                children: [
                  _buildBasicTableCell(bay?.name ?? 'Unknown'),
                  _buildBasicTableCell(bay?.voltageLevel ?? 'N/A'),
                  _buildBasicTableCell(
                    '${energyData['totalImp']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  _buildBasicTableCell(
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
              borderRadius: pw.BorderRadius.circular(5),
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

  static pw.Widget _buildBasicTableCell(String text, {bool isHeader = false}) {
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

  static Future<void> _savePdf(
    Future<Uint8List> pdfBytesFuture,
    String filename,
    String subject,
  ) async {
    final pdfBytes = await pdfBytesFuture;
    await sharePdf(pdfBytes, '$filename.pdf', subject);
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
