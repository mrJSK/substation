// lib/models/tripping_shutdown_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TrippingShutdownEntry {
  final String? id; // Null for new entries
  final String substationId;
  final String bayId;
  final String bayName; // Store bay name for easier display
  final String eventType; // 'Tripping' or 'Shutdown'
  final Timestamp startTime;
  final Timestamp? endTime; // Null if status is 'OPEN'
  final String status; // 'OPEN' or 'CLOSED'
  final String flagsCause; // Text area for flags/cause
  final String?
  reasonForNonFeeder; // NEW FIELD: Reason for non-feeder bay types
  final bool? hasAutoReclose; // Optional, only for 220kV+ bays
  final List<String>?
  phaseFaults; // e.g., ['Rph', 'Yph', 'Bph'], only for Tripping
  final String? distance; // Optional, only for Line bay type (Tripping)
  final String createdBy;
  final Timestamp createdAt;
  final String? closedBy; // User who closed the event
  final Timestamp? closedAt; // Timestamp when the event was closed

  // NEW FIELDS for Shutdown events
  final String? shutdownType; // 'Transmission' or 'Distribution'
  final String? shutdownPersonName;
  final String? shutdownPersonDesignation;

  TrippingShutdownEntry({
    this.id,
    required this.substationId,
    required this.bayId,
    required this.bayName,
    required this.eventType,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.flagsCause,
    this.reasonForNonFeeder, // NEW: Add to copyWith
    this.hasAutoReclose,
    this.phaseFaults,
    this.distance,
    required this.createdBy,
    required this.createdAt,
    this.closedBy,
    this.closedAt,
    // NEW: Initialize new fields
    this.shutdownType,
    this.shutdownPersonName,
    this.shutdownPersonDesignation,
  });

  factory TrippingShutdownEntry.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TrippingShutdownEntry(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      bayId: data['bayId'] ?? '',
      bayName: data['bayName'] ?? '',
      eventType: data['eventType'] ?? '',
      startTime: data['startTime'] as Timestamp,
      endTime: data['endTime'] as Timestamp?,
      status: data['status'] ?? 'OPEN',
      flagsCause: data['flagsCause'] ?? '',
      reasonForNonFeeder: data['reasonForNonFeeder'],
      hasAutoReclose: data['hasAutoReclose'],
      phaseFaults: data['phaseFaults'] != null
          ? List<String>.from(data['phaseFaults'])
          : null,
      distance: data['distance'],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] as Timestamp,
      closedBy: data['closedBy'],
      closedAt: data['closedAt'] as Timestamp?,
      // NEW: Retrieve new fields from Firestore
      shutdownType: data['shutdownType'],
      shutdownPersonName: data['shutdownPersonName'],
      shutdownPersonDesignation: data['shutdownPersonDesignation'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'bayId': bayId,
      'bayName': bayName,
      'eventType': eventType,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'flagsCause': flagsCause,
      'reasonForNonFeeder': reasonForNonFeeder,
      'hasAutoReclose': hasAutoReclose,
      'phaseFaults': phaseFaults,
      'distance': distance,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'closedBy': closedBy,
      'closedAt': closedAt,
      // NEW: Add new fields to Firestore map
      'shutdownType': shutdownType,
      'shutdownPersonName': shutdownPersonName,
      'shutdownPersonDesignation': shutdownPersonDesignation,
    };
  }

  TrippingShutdownEntry copyWith({
    String? id,
    String? substationId,
    String? bayId,
    String? bayName,
    String? eventType,
    Timestamp? startTime,
    Timestamp? endTime,
    String? status,
    String? flagsCause,
    String? reasonForNonFeeder, // NEW: Add to copyWith
    bool? hasAutoReclose,
    List<String>? phaseFaults,
    String? distance,
    String? createdBy,
    Timestamp? createdAt,
    String? closedBy,
    Timestamp? closedAt,
    // NEW: Add new fields to copyWith
    String? shutdownType,
    String? shutdownPersonName,
    String? shutdownPersonDesignation,
  }) {
    return TrippingShutdownEntry(
      id: id ?? this.id,
      substationId: substationId ?? this.substationId,
      bayId: bayId ?? this.bayId,
      bayName: bayName ?? this.bayName,
      eventType: eventType ?? this.eventType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      flagsCause: flagsCause ?? this.flagsCause,
      reasonForNonFeeder:
          reasonForNonFeeder ?? this.reasonForNonFeeder, // NEW: Use in copyWith
      hasAutoReclose: hasAutoReclose ?? this.hasAutoReclose,
      phaseFaults: phaseFaults ?? this.phaseFaults,
      distance: distance ?? this.distance,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      closedBy: closedBy ?? this.closedBy,
      closedAt: closedAt ?? this.closedAt,
      // NEW: Use new fields in copyWith
      shutdownType: shutdownType ?? this.shutdownType,
      shutdownPersonName: shutdownPersonName ?? this.shutdownPersonName,
      shutdownPersonDesignation:
          shutdownPersonDesignation ?? this.shutdownPersonDesignation,
    );
  }
}
