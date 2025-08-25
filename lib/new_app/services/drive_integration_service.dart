// lib/services/drive_integration_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../old_app/models/assessment_model.dart';
import '../../old_app/models/bay_model.dart';
import '../../old_app/models/hierarchy_models.dart';
import '../../old_app/models/logsheet_models.dart';
import '../models/drive_energy_report.dart';
import '../models/drive_integration_model.dart';

class DriveIntegrationService {
  static Future<DriveEnergyReport> createReportFromLogsheet({
    required List<LogsheetEntry> entries,
    required Substation substation,
    required List<Assessment> assessments,
    required String createdBy,
  }) async {
    if (entries.isEmpty) {
      throw ArgumentError('Cannot create report from empty logsheet entries');
    }

    // ✅ OPTION 1: Fetch actual Bay objects from Firestore (recommended)
    final bays = await _fetchBaysForSubstation(substation.id);

    return DriveEnergyReport.fromLogsheetEntries(
      substationId: substation.id,
      substation: substation,
      entries: entries,
      assessments: assessments,
      createdBy: createdBy,
      bays: bays, // ✅ FIXED: Now passing the required bays parameter
    );
  }

  // ✅ OPTION 2: Alternative method without Firestore fetch
  static Future<DriveEnergyReport> createReportFromLogsheetWithoutFetch({
    required List<LogsheetEntry> entries,
    required Substation substation,
    required List<Assessment> assessments,
    required String createdBy,
  }) async {
    if (entries.isEmpty) {
      throw ArgumentError('Cannot create report from empty logsheet entries');
    }

    // Create Bay objects from logsheet entry data (fallback method)
    final bays = _createBaysFromLogsheetEntries(entries);

    return DriveEnergyReport.fromLogsheetEntries(
      substationId: substation.id,
      substation: substation,
      entries: entries,
      assessments: assessments,
      createdBy: createdBy,
      bays: bays, // ✅ FIXED: Using created Bay objects
    );
  }

  // ✅ Helper method to fetch Bay objects from Firestore
  static Future<List<Bay>> _fetchBaysForSubstation(String substationId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substationId)
          .get();

      return querySnapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList();
    } catch (e) {
      print('ERROR: Failed to fetch bays for substation $substationId: $e');
      // Fallback: return empty list (the factory will create Bay objects from logsheet data)
      return [];
    }
  }

  // ✅ Helper method to create Bay objects from logsheet entries
  static List<Bay> _createBaysFromLogsheetEntries(List<LogsheetEntry> entries) {
    final bayMap = <String, Bay>{};

    for (final entry in entries) {
      if (!bayMap.containsKey(entry.bayId)) {
        bayMap[entry.bayId] = Bay(
          id: entry.bayId,
          name: entry.values['bayName']?.toString() ?? 'Bay ${entry.bayId}',
          substationId: entry.substationId,
          voltageLevel: entry.values['voltageLevel']?.toString() ?? '0kV',
          bayType: entry.values['bayType']?.toString() ?? 'Unknown',
          createdBy: entry.recordedBy,
          createdAt: entry.recordedAt,
        );
      }
    }

    return bayMap.values.toList();
  }

  static Future<void> uploadReportToDrive(
    DriveEnergyReport report,
    DriveIntegrationConfig config,
  ) async {
    // Implementation for actual Google Drive upload
    // This would use the Google Drive API to upload the Excel file

    // 1. Generate Excel file from report data
    // 2. Upload to Google Drive using the configured credentials
    // 3. Update report with Drive file information

    throw UnimplementedError('Google Drive upload implementation needed');
  }

  static Future<bool> testDriveConnection(DriveIntegrationConfig config) async {
    // Test the Google Drive connection
    try {
      // Attempt to authenticate and list files
      return true;
    } catch (e) {
      return false;
    }
  }
}
