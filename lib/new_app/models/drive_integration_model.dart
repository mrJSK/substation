// lib/models/drive_integration_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DriveIntegrationConfig {
  final String id;
  final String substationId;
  final String substationName;
  final String googleDriveCredentials;
  final String parentFolderId;
  final Map<String, String> folderStructure; // frequency -> folderId
  final bool autoSyncEnabled;
  final List<String> enabledFrequencies; // ['hourly', 'daily', 'monthly']
  final DriveNamingConvention namingConvention;
  final List<String> notificationEmails;
  final Timestamp createdAt;
  final String createdBy;
  final Timestamp? lastSyncAt;
  final DriveConnectionStatus connectionStatus;

  DriveIntegrationConfig({
    required this.id,
    required this.substationId,
    required this.substationName,
    required this.googleDriveCredentials,
    required this.parentFolderId,
    required this.folderStructure,
    this.autoSyncEnabled = true,
    required this.enabledFrequencies,
    required this.namingConvention,
    this.notificationEmails = const [],
    required this.createdAt,
    required this.createdBy,
    this.lastSyncAt,
    this.connectionStatus = DriveConnectionStatus.pending,
  });

  factory DriveIntegrationConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriveIntegrationConfig(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      substationName: data['substationName'] ?? '',
      googleDriveCredentials: data['googleDriveCredentials'] ?? '',
      parentFolderId: data['parentFolderId'] ?? '',
      folderStructure: Map<String, String>.from(data['folderStructure'] ?? {}),
      autoSyncEnabled: data['autoSyncEnabled'] ?? true,
      enabledFrequencies: List<String>.from(data['enabledFrequencies'] ?? []),
      namingConvention: DriveNamingConvention.fromMap(
        data['namingConvention'] ?? {},
      ),
      notificationEmails: List<String>.from(data['notificationEmails'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? '',
      lastSyncAt: data['lastSyncAt'],
      connectionStatus: DriveConnectionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['connectionStatus'],
        orElse: () => DriveConnectionStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'substationName': substationName,
      'googleDriveCredentials': googleDriveCredentials,
      'parentFolderId': parentFolderId,
      'folderStructure': folderStructure,
      'autoSyncEnabled': autoSyncEnabled,
      'enabledFrequencies': enabledFrequencies,
      'namingConvention': namingConvention.toMap(),
      'notificationEmails': notificationEmails,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'lastSyncAt': lastSyncAt,
      'connectionStatus': connectionStatus.toString().split('.').last,
    };
  }
}

enum DriveConnectionStatus { pending, connected, error, expired, disabled }

class DriveNamingConvention {
  final String prefix;
  final bool includeDate;
  final bool includeTime;
  final bool includeFrequency;
  final String dateFormat; // 'yyyy-MM-dd' or 'dd-MM-yyyy'
  final String separator; // '_' or '-'

  DriveNamingConvention({
    this.prefix = '',
    this.includeDate = true,
    this.includeTime = false,
    this.includeFrequency = true,
    this.dateFormat = 'yyyy-MM-dd',
    this.separator = '_',
  });

  factory DriveNamingConvention.fromMap(Map<String, dynamic> map) {
    return DriveNamingConvention(
      prefix: map['prefix'] ?? '',
      includeDate: map['includeDate'] ?? true,
      includeTime: map['includeTime'] ?? false,
      includeFrequency: map['includeFrequency'] ?? true,
      dateFormat: map['dateFormat'] ?? 'yyyy-MM-dd',
      separator: map['separator'] ?? '_',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prefix': prefix,
      'includeDate': includeDate,
      'includeTime': includeTime,
      'includeFrequency': includeFrequency,
      'dateFormat': dateFormat,
      'separator': separator,
    };
  }

  String generateFileName(
    String substationName,
    String frequency,
    DateTime date,
  ) {
    List<String> parts = [];

    if (prefix.isNotEmpty) parts.add(prefix);
    parts.add(substationName.replaceAll(' ', '_'));
    if (includeFrequency) parts.add(frequency);
    if (includeDate) {
      final formattedDate = dateFormat == 'yyyy-MM-dd'
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          : '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
      parts.add(formattedDate);
    }
    if (includeTime) {
      parts.add(
        '${date.hour.toString().padLeft(2, '0')}-${date.minute.toString().padLeft(2, '0')}',
      );
    }

    return '${parts.join(separator)}.xlsx';
  }
}
