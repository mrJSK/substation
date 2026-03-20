// lib/old_app/services/readings_service.dart
//
// Logsheet readings stored as a subcollection:
//   substations/{substationId}/readings/{readingId}
//
// Query patterns (all single reads, no cascading):
//   Today's readings for a substation  → getForDate(substationId, date)
//   Date range for energy tab           → getForRange(substationId, from, to)
//   Manager view via collection group  → getForSubdivisionDate(subdivisionId, date)

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/logsheet_models.dart';
import '../models/daily_summary_model.dart';

class ReadingsService {
  final FirebaseFirestore _db;
  ReadingsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _readingsRef(String substationId) =>
      _db.collection('substations').doc(substationId).collection('readings');

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// All readings for a substation on a specific date. 1 read.
  Future<List<LogsheetEntry>> getForDate(
    String substationId,
    DateTime date,
  ) async {
    final dateStr = DailySummary.dateStr(date);
    final snap = await _readingsRef(substationId)
        .where('date', isEqualTo: dateStr)
        .get();
    return snap.docs.map(LogsheetEntry.fromFirestore).toList();
  }

  /// Readings for a substation over a date range. 1 read.
  Future<List<LogsheetEntry>> getForRange(
    String substationId,
    DateTime from,
    DateTime to,
  ) async {
    final snap = await _readingsRef(substationId)
        .where('date', isGreaterThanOrEqualTo: DailySummary.dateStr(from))
        .where('date', isLessThanOrEqualTo: DailySummary.dateStr(to))
        .orderBy('date')
        .orderBy('readingHour')
        .get();
    return snap.docs.map(LogsheetEntry.fromFirestore).toList();
  }

  /// Readings for a specific bay on a date. 1 read.
  Future<List<LogsheetEntry>> getForBayDate(
    String substationId,
    String bayId,
    DateTime date,
  ) async {
    final snap = await _readingsRef(substationId)
        .where('bayId', isEqualTo: bayId)
        .where('date', isEqualTo: DailySummary.dateStr(date))
        .get();
    return snap.docs.map(LogsheetEntry.fromFirestore).toList();
  }

  /// Check which hours have been submitted for a substation on a date. 1 read.
  Future<List<int>> getSubmittedHours(
    String substationId,
    DateTime date,
  ) async {
    final snap = await _readingsRef(substationId)
        .where('date', isEqualTo: DailySummary.dateStr(date))
        .where('frequency', isEqualTo: 'hourly')
        .get();
    return snap.docs
        .map((d) => (d.data()['readingHour'] as num?)?.toInt() ?? 0)
        .toSet()
        .toList()
      ..sort();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Submit a reading. Also updates the daily summary atomically.
  Future<void> submit(LogsheetEntry entry) async {
    final batch = _db.batch();

    // Write the reading document
    final readingRef = entry.id != null
        ? _readingsRef(entry.substationId).doc(entry.id)
        : _readingsRef(entry.substationId).doc();
    batch.set(readingRef, entry.toFirestore());

    // Update daily summary energy totals
    final summaryId = DailySummary.docId(
      entry.substationId,
      entry.readingTimestamp.toDate(),
    );
    final summaryRef = _db.collection('daily_summaries').doc(summaryId);

    // Add the submitted hour to shiftsSubmitted array
    if (entry.readingHour != null) {
      batch.set(
        summaryRef,
        {
          'substationId': entry.substationId,
          'subdivisionId': entry.subdivisionId,
          'divisionId': entry.divisionId,
          'date': entry.date,
          'shiftsSubmitted': FieldValue.arrayUnion([entry.readingHour]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Update an existing reading (with a modification reason).
  Future<void> update(LogsheetEntry entry) async {
    if (entry.id == null) throw ArgumentError('Entry id is required for update');
    await _readingsRef(entry.substationId)
        .doc(entry.id)
        .set(entry.toFirestore());
  }
}
