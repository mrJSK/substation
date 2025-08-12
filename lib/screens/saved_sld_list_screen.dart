// lib/screens/saved_sld_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Import necessary packages for PDF generation and sharing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io'; // For File operations
import 'dart:typed_data'; // For Uint8List

import '../models/energy_readings_data.dart';
import '../models/user_model.dart';
import '../models/saved_sld_model.dart'; // Import the SavedSld model
import '../models/assessment_model.dart'; // Import Assessment model for fromMap
import '../utils/snackbar_utils.dart';
import 'subdivision_dashboard_tabs/energy_sld_screen.dart'; // Import EnergySldScreen

class SavedSldListScreen extends StatefulWidget {
  final AppUser currentUser;

  const SavedSldListScreen({super.key, required this.currentUser});

  @override
  State<SavedSldListScreen> createState() => _SavedSldListScreenState();
}

class _SavedSldListScreenState extends State<SavedSldListScreen> {
  bool _isLoading = true;
  List<SavedSld> _savedSlds = [];

  @override
  void initState() {
    super.initState();
    _fetchSavedSlds();
  }

  Future<void> _fetchSavedSlds() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('savedSlds')
          .where('createdBy', isEqualTo: widget.currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _savedSlds = snapshot.docs
            .map((doc) => SavedSld.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print("Error fetching saved SLDs: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load saved SLDs: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteSld(String sldId, String sldName) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete saved SLD "$sldName"? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('savedSlds')
            .doc(sldId)
            .delete();
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Saved SLD "$sldName" deleted successfully!',
          );
        }
        _fetchSavedSlds(); // Refresh the list
      } catch (e) {
        print("Error deleting saved SLD: $e");
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete saved SLD "$sldName": $e',
            isError: true,
          );
        }
      }
    }
  }

  // Function to generate PDF content from SavedSld data
  Future<Uint8List> _generatePdf(SavedSld sld) async {
    final pdf = pw.Document();

    // Reconstruct required data from sld.sldParameters
    final Map<String, dynamic> sldParams = sld.sldParameters;
    final Map<String, dynamic> abstractEnergyData = Map<String, dynamic>.from(
      sldParams['abstractEnergyData'],
    );
    final Map<String, dynamic> busEnergySummaryData = Map<String, dynamic>.from(
      sldParams['busEnergySummary'] ?? {},
    ); // Get bus energy summary
    final List<dynamic> aggregatedFeederDataRaw =
        sldParams['aggregatedFeederEnergyData'] ?? [];
    final Map<String, String> bayNamesLookup = Map<String, String>.from(
      sldParams['bayNamesLookup'] ?? {},
    ); // NEW: Get bay names lookup

    final List<AggregatedFeederEnergyData> aggregatedFeederData =
        aggregatedFeederDataRaw
            .map((e) => AggregatedFeederEnergyData.fromMap(e))
            .toList();

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
              pw.Text(
                '${sld.substationName} - ${sld.name}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                'Period: ${DateFormat('dd-MMM-yyyy').format(sld.startDate.toDate())} to ${DateFormat('dd-MMM-yyyy').format(sld.endDate.toDate())}',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Divider(),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Section 1: Abstract of Substation Energy
            pw.Header(
              level: 0,
              text: 'Abstract of Substation Energy',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfEnergyRow(
                  'Total Import',
                  abstractEnergyData['totalImp'],
                  'MWH',
                ),
                _buildPdfEnergyRow(
                  'Total Export',
                  abstractEnergyData['totalExp'],
                  'MWH',
                ),
                _buildPdfEnergyRow(
                  'Difference',
                  abstractEnergyData['difference'],
                  'MWH',
                ),
                _buildPdfEnergyRow(
                  'Loss Percentage',
                  abstractEnergyData['lossPercentage'],
                  '%',
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Section 2: Abstract of Busbars
            if (busEnergySummaryData.isNotEmpty) ...[
              pw.Header(
                level: 0,
                text: 'Abstract of Busbars',
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide()),
                ),
              ),
              for (var entry in busEnergySummaryData.entries)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Use bayNamesLookup to get the busbar name
                      pw.Text(
                        'Busbar: ${bayNamesLookup[entry.key] ?? entry.key}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      _buildPdfEnergyRow(
                        'Import',
                        entry.value['totalImp'],
                        'MWH',
                      ),
                      _buildPdfEnergyRow(
                        'Export',
                        entry.value['totalExp'],
                        'MWH',
                      ),
                      _buildPdfEnergyRow(
                        'Difference',
                        entry.value['difference'],
                        'MWH',
                      ),
                      _buildPdfEnergyRow(
                        'Loss',
                        entry.value['lossPercentage'],
                        '%',
                      ),
                    ],
                  ),
                ),
              pw.SizedBox(height: 20),
            ],

            // Section 3: Feeder Energy Supplied by Distribution Hierarchy
            pw.Header(
              level: 0,
              text: 'Feeder Energy Supplied To Distribution',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            if (aggregatedFeederData.isNotEmpty)
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
                data: aggregatedFeederData.map((data) {
                  return <String>[
                    data.zoneName,
                    data.circleName,
                    data.divisionName,
                    data.distributionSubdivisionName,
                    data.importedEnergy.toStringAsFixed(2),
                    data.exportedEnergy.toStringAsFixed(2),
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

            // Section 4: Assessments
            pw.Header(
              level: 0,
              text: 'Assessments for this Period',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            if (sld.assessmentsSummary.isNotEmpty)
              pw.Table.fromTextArray(
                context: context,
                headers: <String>[
                  'Bay Name',
                  'Import Adj.',
                  'Export Adj.',
                  'Reason',
                  'Timestamp',
                ],
                data: sld.assessmentsSummary.map((assessmentMap) {
                  final Assessment assessment = Assessment.fromMap(
                    assessmentMap,
                  );
                  return <String>[
                    assessmentMap['bayName'] ??
                        'N/A', // Use bayName from saved map
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
              pw.Text(
                'No assessments were made for this period in the saved SLD.',
              ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // Helper for building energy rows in PDF
  pw.Widget _buildPdfEnergyRow(String label, dynamic value, String unit) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value != null ? '${value.toStringAsFixed(2)} $unit' : 'N/A',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Function to handle PDF generation and sharing
  Future<void> _generateAndSharePdf(SavedSld sld) async {
    try {
      SnackBarUtils.showSnackBar(context, 'Generating PDF...');
      final Uint8List pdfBytes = await _generatePdf(sld);

      final output = await getTemporaryDirectory();
      final String filename =
          '${sld.name.replaceAll(RegExp(r'[^\w\s.-]'), '_')}_energy_report.pdf';
      final file = File('${output.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Energy SLD Report: ${sld.name}');

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'PDF generated and shared successfully!',
        );
      }
    } catch (e) {
      print("Error generating/sharing PDF: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate/share PDF: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Energy SLDs')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedSlds.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No saved SLDs found. Go to an Energy SLD and tap the save icon to save one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _savedSlds.length,
              itemBuilder: (context, index) {
                final sld = _savedSlds[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 3,
                  child: ListTile(
                    title: Text(sld.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Substation: ${sld.substationName}'),
                        Text(
                          'Period: ${DateFormat('dd-MMM-yyyy').format(sld.startDate.toDate())} to ${DateFormat('dd-MMM-yyyy').format(sld.endDate.toDate())}',
                        ),
                        Text(
                          'Saved: ${DateFormat('dd-MMM-yyyy HH:mm').format(sld.createdAt.toDate())}',
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          tooltip: 'View SLD',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => EnergySldScreen(
                                  substationId: sld.substationId,
                                  substationName: sld.substationName,
                                  currentUser: widget.currentUser,
                                  savedSld:
                                      sld, // Pass the entire saved SLD object
                                ),
                              ),
                            );
                          },
                        ),
                        // NEW: Share/Print Button
                        IconButton(
                          icon: const Icon(Icons.share),
                          tooltip: 'Share/Print PDF',
                          onPressed: () => _generateAndSharePdf(sld),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete SLD',
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () => _confirmDeleteSld(sld.id!, sld.name),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
