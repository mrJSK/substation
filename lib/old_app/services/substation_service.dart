// lib/old_app/services/substation_service.dart
//
// All substation reads go through here.
// Key design: bays are embedded in the substation document,
// so fetching a substation also fetches all its bays — ONE read.
//
// Query patterns:
//   Substation user  → getById(id)                       = 1 read
//   Subdivision mgr  → getBySubdivision(subdivisionId)   = 1 read
//   Division mgr     → getByDivision(divisionId)         = 1 read
//   Circle mgr       → getByCircle(circleId)             = 1 read
//   Zone mgr         → getByZone(zoneId)                 = 1 read
//   Admin            → getAll()                          = 1 read

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/substation_model.dart';
import '../models/bay_model.dart';

class SubstationService {
  static const _col = 'substations';
  final FirebaseFirestore _db;

  SubstationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref => _db.collection(_col);

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Fetch one substation (includes all embedded bays). 1 read.
  Future<Substation?> getById(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists) return null;
    return Substation.fromFirestore(doc);
  }

  /// All substations under a subdivision. 1 read.
  Future<List<Substation>> getBySubdivision(String subdivisionId) =>
      _query(_ref.where('subdivisionId', isEqualTo: subdivisionId));

  /// All substations under a division. 1 read.
  Future<List<Substation>> getByDivision(String divisionId) =>
      _query(_ref.where('divisionId', isEqualTo: divisionId));

  /// All substations under a circle. 1 read.
  Future<List<Substation>> getByCircle(String circleId) =>
      _query(_ref.where('circleId', isEqualTo: circleId));

  /// All substations under a zone. 1 read.
  Future<List<Substation>> getByZone(String zoneId) =>
      _query(_ref.where('zoneId', isEqualTo: zoneId));

  /// All substations (admin). 1 read.
  Future<List<Substation>> getAll() => _query(_ref.orderBy('name'));

  Future<List<Substation>> _query(
    Query<Map<String, dynamic>> q,
  ) async {
    final snap = await q.get();
    return snap.docs.map(Substation.fromFirestore).toList();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Create a new substation.
  Future<String> create(Substation substation) async {
    final ref = _ref.doc();
    await ref.set(substation.copyWith(id: ref.id).toFirestore());
    return ref.id;
  }

  /// Update the full substation document (including embedded bays).
  Future<void> update(Substation substation) =>
      _ref.doc(substation.id).set(substation.toFirestore());

  /// Update only the bays array (e.g. after SLD layout edit).
  Future<void> updateBays(String substationId, List<Bay> bays) =>
      _ref.doc(substationId).update({
        'bays': bays.map((b) => b.toMap()).toList(),
      });

  /// Update only the busbars array.
  Future<void> updateBusbars(String substationId, List<Busbar> busbars) =>
      _ref.doc(substationId).update({
        'busbars': busbars.map((b) => b.toMap()).toList(),
      });

  /// Update a single field (e.g. status).
  Future<void> updateField(String substationId, String field, dynamic value) =>
      _ref.doc(substationId).update({field: value});

  /// Delete a substation.
  Future<void> delete(String substationId) => _ref.doc(substationId).delete();
}
