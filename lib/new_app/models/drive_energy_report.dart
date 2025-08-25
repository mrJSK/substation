// lib/models/drive_energy_report.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../old_app/models/assessment_model.dart';
import '../../old_app/models/bay_model.dart';
import '../../old_app/models/energy_readings_data.dart';
import '../../old_app/models/hierarchy_models.dart';
import '../../old_app/models/logsheet_models.dart';

class DriveEnergyReport {
  final String id;
  final String substationId;
  final Substation substation;
  final DateTime reportDate;
  final String frequency; // 'hourly', 'daily', 'monthly'
  final int? hour; // For hourly reports
  final List<BayEnergyData> bayEnergyData;
  final List<Assessment> assessments;
  final Map<String, dynamic> reportMetadata;
  final DriveUploadStatus uploadStatus;
  final String? driveFileId;
  final String? driveFileUrl;
  final Timestamp createdAt;
  final String createdBy;
  final Timestamp? uploadedAt;
  final String? errorMessage;
  final int retryCount;

  DriveEnergyReport({
    required this.id,
    required this.substationId,
    required this.substation,
    required this.reportDate,
    required this.frequency,
    this.hour,
    required this.bayEnergyData,
    this.assessments = const [],
    this.reportMetadata = const {},
    this.uploadStatus = DriveUploadStatus.pending,
    this.driveFileId,
    this.driveFileUrl,
    required this.createdAt,
    required this.createdBy,
    this.uploadedAt,
    this.errorMessage,
    this.retryCount = 0,
  });

  // Convert logsheet entries to energy data
  factory DriveEnergyReport.fromLogsheetEntries({
    required String substationId,
    required Substation substation,
    required List<LogsheetEntry> entries,
    required List<Assessment> assessments,
    required String createdBy,
    required List<Bay> bays, // ✅ ADD: Pass the actual Bay objects
  }) {
    if (entries.isEmpty) {
      throw ArgumentError('Cannot create report from empty entries');
    }

    final firstEntry = entries.first;
    final reportDate = firstEntry.readingTimestamp.toDate();
    final frequency = firstEntry.frequency;
    final hour = firstEntry.readingHour;

    // Convert logsheet entries to energy data
    final bayEnergyData = <BayEnergyData>[];

    for (final entry in entries) {
      // Extract energy readings from logsheet values
      final importReading =
          (entry.values['importReading'] as num?)?.toDouble() ?? 0.0;
      final exportReading =
          (entry.values['exportReading'] as num?)?.toDouble() ?? 0.0;
      final previousImportReading =
          (entry.values['previousImportReading'] as num?)?.toDouble() ?? 0.0;
      final previousExportReading =
          (entry.values['previousExportReading'] as num?)?.toDouble() ?? 0.0;

      // ✅ FIXED: Find the actual Bay object instead of creating a new one
      final bay = bays.firstWhere(
        (b) => b.id == entry.bayId,
        orElse: () => Bay(
          id: entry.bayId,
          name: entry.values['bayName']?.toString() ?? 'Unknown Bay',
          substationId: entry.substationId,
          voltageLevel: entry.values['voltageLevel']?.toString() ?? '0kV',
          bayType: entry.values['bayType']?.toString() ?? 'Unknown',
          createdBy: entry.recordedBy,
          createdAt: entry.recordedAt,
        ),
      );

      final energyData = BayEnergyData.fromReadings(
        bay: bay,
        currentImportReading: importReading,
        currentExportReading: exportReading,
        previousImportReading: previousImportReading,
        previousExportReading: previousExportReading,
        multiplierFactor:
            (entry.values['multiplierFactor'] as num?)?.toDouble() ?? 1.0,
        sourceLogsheetId: entry.id,
        readingTimestamp: entry.readingTimestamp,
      );

      bayEnergyData.add(energyData);
    }

    return DriveEnergyReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      substationId: substationId,
      substation: substation,
      reportDate: reportDate,
      frequency: frequency,
      hour: hour,
      bayEnergyData: bayEnergyData,
      assessments: assessments,
      createdAt: Timestamp.now(),
      createdBy: createdBy,
    );
  }

  // Generate Excel data for Drive upload
  Map<String, dynamic> generateExcelData() {
    final data = <String, dynamic>{};

    // Header information
    data['substation_info'] = {
      'name': substation.name,
      'id': substation.id,
      'voltage_level': substation.voltageLevel,
      'subdivision': substation.subdivisionName,
      'division': substation.divisionName,
      'circle': substation.circleName,
    };

    data['report_info'] = {
      'date': reportDate.toIso8601String(),
      'frequency': frequency,
      'hour': hour,
      'created_by': createdBy,
      'created_at': createdAt.toDate().toIso8601String(),
    };

    // Energy data
    data['energy_readings'] = bayEnergyData
        .map(
          (bay) => {
            'bay_id': bay.bayId,
            'bay_name': bay.computedBayName,
            'bay_type': bay.bay.bayType,
            'voltage_level': bay.bay.voltageLevel,
            'import_reading': bay.importReading,
            'export_reading': bay.exportReading,
            'previous_import_reading': bay.previousImportReading,
            'previous_export_reading': bay.previousExportReading,
            'import_consumed': bay.importConsumed,
            'export_consumed': bay.exportConsumed,
            'multiplier_factor': bay.multiplierFactor,
            'net_energy': bay.netEnergy,
            'has_assessment': bay.hasAssessment,
            'import_adjustment': bay.importAdjustment,
            'export_adjustment': bay.exportAdjustment,
            'adjusted_import_consumed': bay.adjustedImportConsumed,
            'adjusted_export_consumed': bay.adjustedExportConsumed,
          },
        )
        .toList();

    // Assessment data
    if (assessments.isNotEmpty) {
      data['assessments'] = assessments
          .map(
            (assessment) => {
              'id': assessment.id,
              'bay_id': assessment.bayId,
              'assessment_timestamp': assessment.assessmentTimestamp
                  .toDate()
                  .toIso8601String(),
              'import_adjustment': assessment.importAdjustment,
              'export_adjustment': assessment.exportAdjustment,
              'reason': assessment.reason,
              'created_by': assessment.createdBy,
            },
          )
          .toList();
    }

    return data;
  }

  DriveEnergyReport copyWith({
    String? id,
    String? substationId,
    Substation? substation,
    DateTime? reportDate,
    String? frequency,
    int? hour,
    List<BayEnergyData>? bayEnergyData,
    List<Assessment>? assessments,
    Map<String, dynamic>? reportMetadata,
    DriveUploadStatus? uploadStatus,
    String? driveFileId,
    String? driveFileUrl,
    Timestamp? createdAt,
    String? createdBy,
    Timestamp? uploadedAt,
    String? errorMessage,
    int? retryCount,
  }) {
    return DriveEnergyReport(
      id: id ?? this.id,
      substationId: substationId ?? this.substationId,
      substation: substation ?? this.substation,
      reportDate: reportDate ?? this.reportDate,
      frequency: frequency ?? this.frequency,
      hour: hour ?? this.hour,
      bayEnergyData: bayEnergyData ?? this.bayEnergyData,
      assessments: assessments ?? this.assessments,
      reportMetadata: reportMetadata ?? this.reportMetadata,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      driveFileId: driveFileId ?? this.driveFileId,
      driveFileUrl: driveFileUrl ?? this.driveFileUrl,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'substation': substation.toFirestore(),
      'reportDate': Timestamp.fromDate(reportDate),
      'frequency': frequency,
      'hour': hour,
      'bayEnergyData': bayEnergyData.map((data) => data.toMap()).toList(),
      'assessments': assessments
          .map((assessment) => assessment.toFirestore())
          .toList(),
      'reportMetadata': reportMetadata,
      'uploadStatus': uploadStatus.toString().split('.').last,
      'driveFileId': driveFileId,
      'driveFileUrl': driveFileUrl,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'uploadedAt': uploadedAt,
      'errorMessage': errorMessage,
      'retryCount': retryCount,
    };
  }

  // ✅ FIXED: Proper fromFirestore implementation
  factory DriveEnergyReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // First, reconstruct Bay objects from the bayEnergyData
    final List<BayEnergyData> reconstructedBayEnergyData = [];
    final bayEnergyDataList = data['bayEnergyData'] as List? ?? [];

    for (final item in bayEnergyDataList) {
      final bayData = item as Map<String, dynamic>;

      // Create a Bay object from the stored bay data
      final bay = Bay(
        id: bayData['bayId'] ?? '',
        name: bayData['bayName'] ?? 'Unknown Bay',
        substationId: data['substationId'] ?? '',
        voltageLevel: bayData['voltage_level'] ?? '0kV',
        bayType: bayData['bay_type'] ?? 'Unknown',
        createdBy: data['createdBy'] ?? '',
        createdAt: data['createdAt'] ?? Timestamp.now(),
      );

      // Create BayEnergyData with the reconstructed Bay
      final energyData = BayEnergyData.fromMap(bayData, bay);
      reconstructedBayEnergyData.add(energyData);
    }

    return DriveEnergyReport(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      substation: Substation.fromMap(data['substation'] ?? {}),
      reportDate: (data['reportDate'] as Timestamp).toDate(),
      frequency: data['frequency'] ?? '',
      hour: data['hour'],
      bayEnergyData: reconstructedBayEnergyData,
      assessments: (data['assessments'] as List? ?? [])
          .map((item) => Assessment.fromMap(item as Map<String, dynamic>))
          .toList(),
      reportMetadata: Map<String, dynamic>.from(data['reportMetadata'] ?? {}),
      uploadStatus: DriveUploadStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['uploadStatus'],
        orElse: () => DriveUploadStatus.pending,
      ),
      driveFileId: data['driveFileId'],
      driveFileUrl: data['driveFileUrl'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? '',
      uploadedAt: data['uploadedAt'],
      errorMessage: data['errorMessage'],
      retryCount: data['retryCount'] ?? 0,
    );
  }
}

enum DriveUploadStatus { pending, uploading, completed, failed, retrying }
