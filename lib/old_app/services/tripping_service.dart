// lib/old_app/services/tripping_service.dart
//
// Tripping/shutdown events stored as a subcollection:
//   substations/{substationId}/tripping/{eventId}
//
// Substation users: real-time stream on their substation's subcollection.
// Managers: collection group query filtered by subdivisionId/divisionId.
//
// Real-time is ONLY used for the tripping screen — everything else is one-time.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tripping_shutdown_model.dart';

class TrippingService {
  final FirebaseFirestore _db;
  TrippingService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String substationId) =>
      _db.collection('substations').doc(substationId).collection('tripping');

  // ── Real-time stream (tripping screen only) ────────────────────────────────

  /// Live stream of open events for one substation.
  /// Use this ONLY on the tripping/shutdown screen.
  Stream<List<TrippingShutdownEntry>> streamOpen(String substationId) =>
      _col(substationId)
          .where('status', isEqualTo: 'OPEN')
          .orderBy('startTime', descending: true)
          .snapshots()
          .map(
            (s) => s.docs.map(TrippingShutdownEntry.fromFirestore).toList(),
          );

  /// Live stream of ALL events (open + closed) for one substation.
  Stream<List<TrippingShutdownEntry>> streamAll(String substationId) =>
      _col(substationId)
          .orderBy('startTime', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (s) => s.docs.map(TrippingShutdownEntry.fromFirestore).toList(),
          );

  // ── One-time reads (for manager views, reports) ────────────────────────────

  /// Recent events for one substation. 1 read.
  Future<List<TrippingShutdownEntry>> getForSubstation(
    String substationId, {
    int limit = 50,
  }) async {
    final snap = await _col(substationId)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(TrippingShutdownEntry.fromFirestore).toList();
  }

  /// Events for a subdivision (manager view). 1 collection group read.
  Future<List<TrippingShutdownEntry>> getForSubdivision(
    String subdivisionId, {
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collectionGroup('tripping')
        .where('subdivisionId', isEqualTo: subdivisionId);

    if (from != null) {
      q = q.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }

    final snap = await q
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(TrippingShutdownEntry.fromFirestore).toList();
  }

  /// Events for a division (division manager view). 1 collection group read.
  Future<List<TrippingShutdownEntry>> getForDivision(
    String divisionId, {
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collectionGroup('tripping')
        .where('divisionId', isEqualTo: divisionId);

    if (from != null) {
      q = q.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }

    final snap = await q
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(TrippingShutdownEntry.fromFirestore).toList();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Log a new tripping/shutdown event. Also increments daily summary count.
  Future<String> create(TrippingShutdownEntry entry) async {
    final batch = _db.batch();

    final eventRef = _col(entry.substationId).doc();
    batch.set(eventRef, entry.toFirestore());

    // Bump tripping/shutdown count on today's daily summary
    final today = entry.startTime.toDate();
    final summaryId = '${entry.substationId}_'
        '${today.year.toString().padLeft(4, '0')}'
        '${today.month.toString().padLeft(2, '0')}'
        '${today.day.toString().padLeft(2, '0')}';

    final countField = entry.eventType == 'Tripping'
        ? 'trippingCount'
        : 'shutdownCount';

    batch.set(
      _db.collection('daily_summaries').doc(summaryId),
      {
        'substationId': entry.substationId,
        'subdivisionId': entry.subdivisionId,
        'divisionId': entry.divisionId,
        countField: FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return eventRef.id;
  }

  /// Close an open event (restore power).
  Future<void> close(
    String substationId,
    String eventId, {
    required String closedBy,
    required Timestamp closedAt,
    required Timestamp endTime,
    required double outageMinutes,
  }) async {
    final batch = _db.batch();

    batch.update(_col(substationId).doc(eventId), {
      'status': 'CLOSED',
      'closedBy': closedBy,
      'closedAt': closedAt,
      'endTime': endTime,
    });

    // Add outage duration to today's daily summary
    final day = closedAt.toDate();
    final summaryId = '${substationId}_'
        '${day.year.toString().padLeft(4, '0')}'
        '${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}';

    batch.set(
      _db.collection('daily_summaries').doc(summaryId),
      {
        'totalOutageMinutes': FieldValue.increment(outageMinutes),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Update an existing event.
  Future<void> update(TrippingShutdownEntry entry) async {
    if (entry.id == null) throw ArgumentError('Event id required for update');
    await _col(entry.substationId).doc(entry.id).set(entry.toFirestore());
  }
}
