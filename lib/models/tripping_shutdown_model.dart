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
  phaseFaults; // e.g., ['Rph', 'Yph', 'RYB'], only for Tripping
  final String? distance; // Optional, only for Line bay type (Tripping)
  final String createdBy;
  final Timestamp createdAt;
  final String? closedBy; // User who closed the event
  final Timestamp? closedAt; // Timestamp when the event was closed

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
    this.reasonForNonFeeder, // NEW: Add to constructor
    this.hasAutoReclose,
    this.phaseFaults,
    this.distance,
    required this.createdBy,
    required this.createdAt,
    this.closedBy,
    this.closedAt,
  });

  factory TrippingShutdownEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TrippingShutdownEntry(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      bayId: data['bayId'] ?? '',
      bayName: data['bayName'] ?? '',
      eventType: data['eventType'] ?? '',
      startTime: data['startTime'] ?? Timestamp.now(),
      endTime: data['endTime'],
      status: data['status'] ?? 'OPEN',
      flagsCause: data['flagsCause'] ?? '',
      reasonForNonFeeder:
          data['reasonForNonFeeder'], // NEW: Read from Firestore
      hasAutoReclose: data['hasAutoReclose'],
      phaseFaults: (data['phaseFaults'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      distance: data['distance'],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      closedBy: data['closedBy'],
      closedAt: data['closedAt'],
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
      'reasonForNonFeeder': reasonForNonFeeder, // NEW: Write to Firestore
      'hasAutoReclose': hasAutoReclose,
      'phaseFaults': phaseFaults,
      'distance': distance,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'closedBy': closedBy,
      'closedAt': closedAt,
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
    );
  }
}
