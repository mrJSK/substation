// lib/old_app/services/daily_summary_service.dart
//
// Pre-aggregated daily data per substation.
// Collection: 'daily_summaries'
// Document ID: {substationId}_{YYYYMMDD}
//
// This is the KEY service for subdivision manager performance.
// Instead of reading N substations × M bays × K readings,
// the manager reads ONE query and gets aggregated data for ALL substations.
//
// Manager dashboard cost:
//   Old: 100-200 reads   New: 2 reads (substations + daily_summaries)

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_summary_model.dart';

class DailySummaryService {
  final FirebaseFirestore _db;
  DailySummaryService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('daily_summaries');

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Today's summary for one substation. 1 read.
  Future<DailySummary?> getForSubstation(
    String substationId, {
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final doc =
        await _col.doc(DailySummary.docId(substationId, d)).get();
    if (!doc.exists) return null;
    return DailySummary.fromFirestore(doc);
  }

  /// Summaries for ALL substations under a subdivision on a given date.
  /// This is the core manager query — 1 read for the whole dashboard.
  Future<List<DailySummary>> getForSubdivision(
    String subdivisionId, {
    DateTime? date,
  }) async {
    final dateStr = DailySummary.dateStr(date ?? DateTime.now());
    final snap = await _col
        .where('subdivisionId', isEqualTo: subdivisionId)
        .where('date', isEqualTo: dateStr)
        .get();
    return snap.docs.map(DailySummary.fromFirestore).toList();
  }

  /// Summaries for ALL substations under a division on a given date. 1 read.
  Future<List<DailySummary>> getForDivision(
    String divisionId, {
    DateTime? date,
  }) async {
    final dateStr = DailySummary.dateStr(date ?? DateTime.now());
    final snap = await _col
        .where('divisionId', isEqualTo: divisionId)
        .where('date', isEqualTo: dateStr)
        .get();
    return snap.docs.map(DailySummary.fromFirestore).toList();
  }

  /// Date range for one substation (energy tab). 1 read.
  Future<List<DailySummary>> getForSubstationRange(
    String substationId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _col
        .where('substationId', isEqualTo: substationId)
        .where('date', isGreaterThanOrEqualTo: DailySummary.dateStr(from))
        .where('date', isLessThanOrEqualTo: DailySummary.dateStr(to))
        .orderBy('date')
        .get();
    return snap.docs.map(DailySummary.fromFirestore).toList();
  }

  /// Date range for a subdivision (manager energy tab). 1 read.
  Future<List<DailySummary>> getForSubdivisionRange(
    String subdivisionId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _col
        .where('subdivisionId', isEqualTo: subdivisionId)
        .where('date', isGreaterThanOrEqualTo: DailySummary.dateStr(from))
        .where('date', isLessThanOrEqualTo: DailySummary.dateStr(to))
        .orderBy('date')
        .get();
    return snap.docs.map(DailySummary.fromFirestore).toList();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Recalculate and write the full daily summary for a substation.
  /// Called after all readings for a day are submitted.
  Future<void> upsert(DailySummary summary) async {
    final id = DailySummary.docId(
      summary.substationId,
      DateTime.parse(summary.date),
    );
    await _col.doc(id).set(summary.toFirestore(), SetOptions(merge: true));
  }

  /// Update energy totals for a specific bay reading submission.
  /// Uses merge so partial updates don't overwrite other bays' data.
  Future<void> updateEnergyForBay({
    required String substationId,
    required String substationName,
    required String subdivisionId,
    required String divisionId,
    required String circleId,
    required String zoneId,
    required DateTime date,
    required String bayId,
    required double importKwh,
    required double exportKwh,
  }) async {
    final id = DailySummary.docId(substationId, date);
    final dateStr = DailySummary.dateStr(date);

    await _col.doc(id).set(
      {
        'substationId': substationId,
        'substationName': substationName,
        'subdivisionId': subdivisionId,
        'divisionId': divisionId,
        'circleId': circleId,
        'zoneId': zoneId,
        'date': dateStr,
        'importByBay.$bayId': importKwh,
        'exportByBay.$bayId': exportKwh,
        // totalImport/totalExport recalculated by Cloud Function or on read
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
