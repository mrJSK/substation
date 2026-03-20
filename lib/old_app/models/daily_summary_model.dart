// lib/old_app/models/daily_summary_model.dart
//
// One document per substation per day, written when readings are submitted.
// Collection: 'daily_summaries'
// Document ID: {substationId}_{YYYYMMDD}  e.g. "abc123_20260320"
//
// Subdivision managers read these to get their full dashboard in 2 reads:
//   1. substations.where('subdivisionId', ==, myId)       → list + bays
//   2. daily_summaries.where('subdivisionId', ==, myId)   → today's energy/status

import 'package:cloud_firestore/cloud_firestore.dart';

class DailySummary {
  final String substationId;
  final String substationName;

  /// Denormalized for manager-level queries.
  final String subdivisionId;
  final String divisionId;
  final String circleId;
  final String zoneId;

  /// "2026-03-20" — string for easy equality/range queries.
  final String date;

  // Energy totals (kWh)
  final double totalImport;
  final double totalExport;
  final Map<String, double> importByBay; // bayId → kWh
  final Map<String, double> exportByBay;

  // Events
  final int trippingCount;
  final int shutdownCount;
  final double totalOutageMinutes;

  /// Hours for which readings have been submitted (e.g. [0, 6, 12, 18]).
  final List<int> shiftsSubmitted;

  /// True when all required readings for the day are in.
  final bool isComplete;

  final Timestamp updatedAt;

  const DailySummary({
    required this.substationId,
    required this.substationName,
    required this.subdivisionId,
    required this.divisionId,
    required this.circleId,
    required this.zoneId,
    required this.date,
    this.totalImport = 0,
    this.totalExport = 0,
    this.importByBay = const {},
    this.exportByBay = const {},
    this.trippingCount = 0,
    this.shutdownCount = 0,
    this.totalOutageMinutes = 0,
    this.shiftsSubmitted = const [],
    this.isComplete = false,
    required this.updatedAt,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Document ID for a given substation + date.
  static String docId(String substationId, DateTime date) =>
      '${substationId}_${_pad(date.year, 4)}${_pad(date.month, 2)}${_pad(date.day, 2)}';

  /// "YYYY-MM-DD" string from a DateTime.
  static String dateStr(DateTime date) =>
      '${_pad(date.year, 4)}-${_pad(date.month, 2)}-${_pad(date.day, 2)}';

  static String _pad(int n, int width) => n.toString().padLeft(width, '0');

  // ── Serialization ─────────────────────────────────────────────────────────

  factory DailySummary.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DailySummary(
      substationId: d['substationId'] ?? '',
      substationName: d['substationName'] ?? '',
      subdivisionId: d['subdivisionId'] ?? '',
      divisionId: d['divisionId'] ?? '',
      circleId: d['circleId'] ?? '',
      zoneId: d['zoneId'] ?? '',
      date: d['date'] ?? '',
      totalImport: (d['totalImport'] as num?)?.toDouble() ?? 0,
      totalExport: (d['totalExport'] as num?)?.toDouble() ?? 0,
      importByBay: _doubleMap(d['importByBay']),
      exportByBay: _doubleMap(d['exportByBay']),
      trippingCount: (d['trippingCount'] as num?)?.toInt() ?? 0,
      shutdownCount: (d['shutdownCount'] as num?)?.toInt() ?? 0,
      totalOutageMinutes: (d['totalOutageMinutes'] as num?)?.toDouble() ?? 0,
      shiftsSubmitted:
          (d['shiftsSubmitted'] as List<dynamic>? ?? [])
              .map((e) => (e as num).toInt())
              .toList(),
      isComplete: d['isComplete'] ?? false,
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  static Map<String, double> _doubleMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map).map(
      (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'substationId': substationId,
    'substationName': substationName,
    'subdivisionId': subdivisionId,
    'divisionId': divisionId,
    'circleId': circleId,
    'zoneId': zoneId,
    'date': date,
    'totalImport': totalImport,
    'totalExport': totalExport,
    'importByBay': importByBay,
    'exportByBay': exportByBay,
    'trippingCount': trippingCount,
    'shutdownCount': shutdownCount,
    'totalOutageMinutes': totalOutageMinutes,
    'shiftsSubmitted': shiftsSubmitted,
    'isComplete': isComplete,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  DailySummary copyWith({
    String? substationId,
    String? substationName,
    String? subdivisionId,
    String? divisionId,
    String? circleId,
    String? zoneId,
    String? date,
    double? totalImport,
    double? totalExport,
    Map<String, double>? importByBay,
    Map<String, double>? exportByBay,
    int? trippingCount,
    int? shutdownCount,
    double? totalOutageMinutes,
    List<int>? shiftsSubmitted,
    bool? isComplete,
    Timestamp? updatedAt,
  }) => DailySummary(
    substationId: substationId ?? this.substationId,
    substationName: substationName ?? this.substationName,
    subdivisionId: subdivisionId ?? this.subdivisionId,
    divisionId: divisionId ?? this.divisionId,
    circleId: circleId ?? this.circleId,
    zoneId: zoneId ?? this.zoneId,
    date: date ?? this.date,
    totalImport: totalImport ?? this.totalImport,
    totalExport: totalExport ?? this.totalExport,
    importByBay: importByBay ?? this.importByBay,
    exportByBay: exportByBay ?? this.exportByBay,
    trippingCount: trippingCount ?? this.trippingCount,
    shutdownCount: shutdownCount ?? this.shutdownCount,
    totalOutageMinutes: totalOutageMinutes ?? this.totalOutageMinutes,
    shiftsSubmitted: shiftsSubmitted ?? this.shiftsSubmitted,
    isComplete: isComplete ?? this.isComplete,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
