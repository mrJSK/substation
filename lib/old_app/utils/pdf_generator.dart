import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/bay_model.dart';
import '../models/bay_connection_model.dart';
import '../models/energy_readings_data.dart';
import '../models/signature_models.dart';
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
  final List<SignatureData>? signatures;
  final List<DistributionFeederData>? distributionFeederData;

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
    this.signatures,
    this.distributionFeederData,
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

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      minX = 0;
      minY = 0;
      maxX = 800;
      maxY = 600;
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
          final double pageContentWidth = PdfPageFormat.a4.width - 40;
          final double totalPageHeight = PdfPageFormat.a4.height - 40;
          final double headerHeight = totalPageHeight * 0.08;
          final double sldAreaHeight = totalPageHeight * 0.65;

          final double imageAspect =
              (data.sldBaseLogicalWidth > 0 && data.sldBaseLogicalHeight > 0)
              ? (data.sldBaseLogicalWidth / data.sldBaseLogicalHeight)
              : (16 / 9);

          double desiredWidth = pageContentWidth;
          double desiredHeight = desiredWidth / imageAspect;

          if (desiredHeight > sldAreaHeight) {
            desiredHeight = sldAreaHeight;
            desiredWidth = desiredHeight * imageAspect;
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: headerHeight, child: _buildHeader(data)),
              pw.SizedBox(height: 12),
              pw.Container(
                height: sldAreaHeight,
                width: pageContentWidth,
                child: pw.Center(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey300, width: 1),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Center(
                      child: pw.Image(
                        sldImage,
                        width: desiredWidth,
                        height: desiredHeight,
                        fit: pw.BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              _buildTableHeader(),
              pw.SizedBox(height: 8),
              _buildConsolidatedEnergyTable(data),
              pw.SizedBox(height: 12),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageHeader(
                "Distribution & Assessment Analysis - Page 2",
                data,
              ),
              pw.SizedBox(height: 16),
              _buildDistributionTable(data),
              pw.SizedBox(height: 20),
              _buildAssessmentsTable(data),
              pw.SizedBox(height: 30),
              _buildSignatureSection(data),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
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
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Text(
              'Single Line Diagram - $title',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Container(
            height: 300,
            padding: const pw.EdgeInsets.all(12),
            child: pw.Center(child: pw.Image(sldImage, fit: pw.BoxFit.contain)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeader(PdfGeneratorData data) {
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
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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

  static pw.Widget _buildPageHeader(String title, PdfGeneratorData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.Text(
            data.substationName,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

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

  static pw.Widget _buildConsolidatedEnergyTable(PdfGeneratorData data) {
    final abstract = data.abstractEnergyData;
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
        padding: const pw.EdgeInsets.all(6),
        child: pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: _buildColumnWidths(busbars.length),
          children: [
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

  static pw.Widget _buildDistributionTable(PdfGeneratorData data) {
    if (data.aggregatedFeederData.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          border: pw.Border.all(color: PdfColors.grey300, width: 1),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'No Distribution Data Available',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Feeder Energy Supplied by Distribution Hierarchy',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(2.0),
              4: pw.FlexColumnWidth(1.2),
              5: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeaderCell('D-Zone'),
                  _buildTableHeaderCell('D-Circle'),
                  _buildTableHeaderCell('D-Division'),
                  _buildTableHeaderCell('D-Subdivision'),
                  _buildTableHeaderCell('Import (MWH)'),
                  _buildTableHeaderCell('Export (MWH)'),
                ],
              ),
              ...data.aggregatedFeederData.take(15).map((feeder) {
                // feeder is AggregatedFeederEnergyData
                final importMWh = (feeder.importedEnergy) / 1000;
                final exportMWh = (feeder.exportedEnergy) / 1000;
                return pw.TableRow(
                  children: [
                    _buildTableDataCell(feeder.zoneName),
                    _buildTableDataCell(feeder.circleName),
                    _buildTableDataCell(feeder.divisionName),
                    _buildTableDataCell(feeder.distributionSubdivisionName),
                    _buildTableDataCell(importMWh.toStringAsFixed(2)),
                    _buildTableDataCell(exportMWh.toStringAsFixed(2)),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildAssessmentsTable(PdfGeneratorData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Energy Assessments',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),

        if (data.assessmentsForPdf.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'No assessments were made for this period.',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          )
        else
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.0),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(3.0),
                4: pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeaderCell('Bay Name'),
                    _buildTableHeaderCell('Import Adj.'),
                    _buildTableHeaderCell('Export Adj.'),
                    _buildTableHeaderCell('Reason'),
                    _buildTableHeaderCell('Timestamp'),
                  ],
                ),
                ...data.assessmentsForPdf.map((assessment) {
                  final timestamp = assessment['timestamp'] != null
                      ? (assessment['timestamp'] as Timestamp).toDate()
                      : DateTime.now();

                  return pw.TableRow(
                    children: [
                      _buildTableDataCell(assessment['bayName'] ?? 'N/A'),
                      _buildTableDataCell(
                        assessment['importAdjustment']?.toStringAsFixed(2) ??
                            '0.00',
                      ),
                      _buildTableDataCell(
                        assessment['exportAdjustment']?.toStringAsFixed(2) ??
                            '0.00',
                      ),
                      _buildTableDataCell(
                        assessment['reason'] ?? 'No reason provided',
                      ),
                      _buildTableDataCell(
                        '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildSignatureSection(PdfGeneratorData data) {
    final signatures = data.signatures ?? <SignatureData>[];
    final List<SignatureData> finalSignatures = List.from(signatures);

    // Build rows in groups of 3
    List<pw.Widget> signatureRows = [];
    const int signaturesPerRow = 3;

    for (int i = 0; i < finalSignatures.length; i += signaturesPerRow) {
      final rowSignatures = finalSignatures
          .skip(i)
          .take(signaturesPerRow)
          .toList();

      signatureRows.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rowSignatures.map((sig) {
            return pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Signature line
                    pw.Container(
                      height: 50,
                      alignment: pw.Alignment.bottomCenter,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      sig.name.isNotEmpty ? sig.name : ' ', // avoid collapsing
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      sig.designation,
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sig.department,
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );

      if (i + signaturesPerRow < finalSignatures.length) {
        signatureRows.add(pw.SizedBox(height: 30));
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Signatures',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'I certify that the above energy account is correct:',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),

        if (finalSignatures.isEmpty)
          pw.Text(
            'No signatures provided.',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          )
        else
          ...signatureRows,
      ],
    );
  }

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

  static Map<int, pw.TableColumnWidth> _buildColumnWidths(int busbarCount) {
    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FlexColumnWidth(1.8),
    };
    for (int i = 1; i <= busbarCount; i++) {
      columnWidths[i] = const pw.FlexColumnWidth(1.2);
    }
    columnWidths[busbarCount + 1] = const pw.FlexColumnWidth(1.2);
    return columnWidths;
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableDataCell(String text, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

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

  /// Generates the monthly Energy Account PDF directly from data.
  /// No canvas screenshot required — pure vector output.
  /// Matches the format in the Excel/sample image.
  static Future<Uint8List> generateMonthlyEnergyAccountPdf({
    required String substationName,
    required String substationVoltage, // e.g. "132 KV"
    required String monthYear, // e.g. "M/O-02/2026"
    required Map<String, BayEnergyData> bayEnergyData,
    required Map<String, Bay> baysMap,
    required Map<String, Map<String, double>> busEnergySummary,
    required List<Map<String, dynamic>> assessments,
    required List<SignatureData> signatures,
    String? remarks,
  }) async {
    final pdf = pw.Document();

    // Group non-busbar bays by voltage level, sorted high→low
    final Map<String, List<Bay>> baysByVoltage = {};
    for (final bay in baysMap.values) {
      if (bay.bayType.toLowerCase() == 'busbar') continue;
      final vl = bay.voltageLevel;
      baysByVoltage.putIfAbsent(vl, () => []).add(bay);
    }
    final sortedVoltages = baysByVoltage.keys.toList()
      ..sort((a, b) => _extractVoltageValue(b).compareTo(_extractVoltageValue(a)));

    // Compute abstract totals per busbar
    final Map<String, double> busImp = {};
    final Map<String, double> busExp = {};
    for (final entry in busEnergySummary.entries) {
      busImp[entry.key] = entry.value['totalImp'] ?? 0.0;
      busExp[entry.key] = entry.value['totalExp'] ?? 0.0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        build: (pw.Context ctx) {
          return [
            _buildEaHeader(substationVoltage, substationName, monthYear),
            pw.SizedBox(height: 6),
            ...sortedVoltages.expand((vl) => [
              _buildVoltageGroupHeader(vl),
              pw.SizedBox(height: 3),
              _buildFeedersTable(
                vl,
                baysByVoltage[vl]!,
                bayEnergyData,
              ),
              pw.SizedBox(height: 8),
            ]),
            _buildAbstractTable(
              baysMap,
              busImp,
              busExp,
              busEnergySummary,
            ),
            if (assessments.isNotEmpty || (remarks != null && remarks.isNotEmpty)) ...[
              pw.SizedBox(height: 8),
              _buildRemarksSection(assessments, remarks),
            ],
            pw.SizedBox(height: 12),
            _buildEaSignatureSection(signatures),
          ];
        },
        footer: (pw.Context ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildEaHeader(
    String voltage,
    String substationName,
    String monthYear,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'ENERGY ACCOUNT OF $voltage SUB-STATION $substationName',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.black, width: 0.8),
              ),
            ),
            child: pw.Text(
              monthYear,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildVoltageGroupHeader(String voltageLevel) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      child: pw.Text(
        '$voltageLevel FEEDERS / LINES',
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildFeedersTable(
    String voltageLevel,
    List<Bay> bays,
    Map<String, BayEnergyData> bayEnergyData,
  ) {
    const border = pw.TableBorder(
      bottom: pw.BorderSide(width: 0.5),
      top: pw.BorderSide(width: 0.5),
      left: pw.BorderSide(width: 0.5),
      right: pw.BorderSide(width: 0.5),
      horizontalInside: pw.BorderSide(width: 0.3, color: PdfColors.grey400),
      verticalInside: pw.BorderSide(width: 0.3, color: PdfColors.grey400),
    );

    final headerCells = [
      'Sr.',
      'Bay / Feeder Name',
      'Consumer / Destination',
      'Bay Type',
      'CT Ratio',
      'MF',
      'Prev. Reading\n(Imp / Exp)',
      'Curr. Reading\n(Imp / Exp)',
      'Units Consumed\n(Imp / Exp)',
    ];

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: headerCells.map((h) => _eaHeaderCell(h)).toList(),
    );

    final dataRows = bays.asMap().entries.map((entry) {
      final i = entry.key;
      final bay = entry.value;
      final ed = bayEnergyData[bay.id];

      final mf = bay.multiplyingFactor?.toStringAsFixed(2) ?? '-';
      final prevImp = ed != null
          ? ed.previousImportReading.toStringAsFixed(2)
          : '-';
      final prevExp = ed != null
          ? ed.previousExportReading.toStringAsFixed(2)
          : '-';
      final currImp =
          ed != null ? ed.importReading.toStringAsFixed(2) : '-';
      final currExp =
          ed != null ? ed.exportReading.toStringAsFixed(2) : '-';
      final unitsImp = ed != null
          ? ed.adjustedImportConsumed.toStringAsFixed(2)
          : '-';
      final unitsExp = ed != null
          ? ed.adjustedExportConsumed.toStringAsFixed(2)
          : '-';

      // CT ratio from make field or derive from MF / description
      final ctRatio = bay.make ?? '-';
      final consumer = bay.description?.isNotEmpty == true
          ? bay.description!
          : bay.contactPerson ?? '-';

      return pw.TableRow(
        decoration: i.isEven
            ? const pw.BoxDecoration(color: PdfColors.white)
            : const pw.BoxDecoration(color: PdfColors.grey50),
        children: [
          _eaCell('${i + 1}'),
          _eaCell(bay.name, bold: true),
          _eaCell(consumer),
          _eaCell(bay.bayType),
          _eaCell(ctRatio),
          _eaCell(mf),
          _eaCell('$prevImp\n$prevExp'),
          _eaCell('$currImp\n$currExp'),
          _eaCell('$unitsImp\n$unitsExp', bold: true),
        ],
      );
    }).toList();

    return pw.Table(
      border: border,
      columnWidths: const {
        0: pw.FixedColumnWidth(20),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FixedColumnWidth(36),
        6: pw.FlexColumnWidth(1.4),
        7: pw.FlexColumnWidth(1.4),
        8: pw.FlexColumnWidth(1.4),
      },
      children: [headerRow, ...dataRows],
    );
  }

  static pw.Widget _buildAbstractTable(
    Map<String, Bay> baysMap,
    Map<String, double> busImp,
    Map<String, double> busExp,
    Map<String, Map<String, double>> busEnergySummary,
  ) {
    final busbars = busEnergySummary.keys
        .map((id) => baysMap[id])
        .whereType<Bay>()
        .toList()
      ..sort((a, b) =>
          _extractVoltageValue(b.voltageLevel)
              .compareTo(_extractVoltageValue(a.voltageLevel)));

    if (busbars.isEmpty) return pw.SizedBox();

    double totalImp = busImp.values.fold(0.0, (a, b) => a + b);
    double totalExp = busExp.values.fold(0.0, (a, b) => a + b);
    double diff = totalImp - totalExp;
    double lossPercent = totalImp > 0 ? (diff / totalImp * 100) : 0;

    final header = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _eaHeaderCell(''),
        ...busbars.map((b) => _eaHeaderCell('${b.voltageLevel} BUS')),
        _eaHeaderCell('ABSTRACT\nOF S/S'),
      ],
    );

    pw.TableRow buildRow(String label, List<String> values, String total,
        {bool bold = false}) {
      return pw.TableRow(children: [
        _eaCell(label, bold: bold),
        ...values.map((v) => _eaCell(v, bold: bold)),
        _eaCell(total, bold: true),
      ]);
    }

    final rows = [
      buildRow(
        'Imp.',
        busbars
            .map((b) => (busImp[b.id] ?? 0.0).toStringAsFixed(2))
            .toList(),
        totalImp.toStringAsFixed(2),
        bold: true,
      ),
      buildRow(
        'Exp.',
        busbars
            .map((b) => (busExp[b.id] ?? 0.0).toStringAsFixed(2))
            .toList(),
        totalExp.toStringAsFixed(2),
        bold: true,
      ),
      buildRow(
        'Diff.',
        busbars.map((b) {
          final d = (busImp[b.id] ?? 0.0) - (busExp[b.id] ?? 0.0);
          return d.toStringAsFixed(2);
        }).toList(),
        diff.toStringAsFixed(2),
      ),
      buildRow(
        '% Loss',
        busbars.map((b) {
          final imp = busImp[b.id] ?? 0.0;
          final exp = busExp[b.id] ?? 0.0;
          final pct = imp > 0 ? ((imp - exp) / imp * 100) : 0.0;
          return '${pct.toStringAsFixed(3)}%';
        }).toList(),
        '${lossPercent.toStringAsFixed(3)}%',
      ),
    ];

    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(40),
    };
    for (int i = 1; i <= busbars.length; i++) {
      colWidths[i] = const pw.FlexColumnWidth(1);
    }
    colWidths[busbars.length + 1] = const pw.FlexColumnWidth(1.2);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ABSTRACT / SUMMARY',
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey600, width: 0.5),
          columnWidths: colWidths,
          children: [header, ...rows],
        ),
      ],
    );
  }

  static pw.Widget _buildRemarksSection(
    List<Map<String, dynamic>> assessments,
    String? remarks,
  ) {
    final lines = <pw.Widget>[];

    if (remarks != null && remarks.isNotEmpty) {
      lines.add(
        pw.Text(
          'Note: $remarks',
          style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic),
        ),
      );
    }

    for (final a in assessments) {
      final bayName = a['bayName'] ?? a['bay_name'] ?? '';
      final imp = (a['importAdjustment'] as num?)?.toStringAsFixed(2) ?? '0';
      final exp = (a['exportAdjustment'] as num?)?.toStringAsFixed(2) ?? '0';
      final reason = a['reason'] ?? '';
      lines.add(
        pw.Text(
          'Assessment – $bayName: Imp adj $imp, Exp adj $exp. $reason',
          style: const pw.TextStyle(fontSize: 8),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
        color: PdfColors.yellow50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Remarks / Assessments :',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          ...lines,
        ],
      ),
    );
  }

  static pw.Widget _buildEaSignatureSection(List<SignatureData> signatures) {
    if (signatures.isEmpty) {
      // Default roles as in the sample image
      final now = DateTime.now();
      signatures = [
        SignatureData(name: '', designation: 'SDO', department: '', signedAt: now),
        SignatureData(name: '', designation: 'AE (T&C)', department: '', signedAt: now),
        SignatureData(name: '', designation: 'E.E. (Test)', department: '', signedAt: now),
        SignatureData(name: '', designation: 'E.E. (Trans.)', department: '', signedAt: now),
      ];
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: signatures
          .map(
            (sig) => pw.Expanded(
              child: pw.Container(
                margin:
                    const pw.EdgeInsets.symmetric(horizontal: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      height: 35,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      sig.designation,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (sig.department.isNotEmpty)
                      pw.Text(
                        sig.department,
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _eaHeaderCell(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(
            vertical: 4, horizontal: 3),
        child: pw.Text(
          text,
          style: pw.TextStyle(
              fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      );

  static pw.Widget _eaCell(String text, {bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(
            vertical: 3, horizontal: 3),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight:
                bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );

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
