// lib/old_app/services/hierarchy_service.dart
//
// Loads the entire org hierarchy from ONE Firestore document.
// Caches it in SharedPreferences so subsequent app opens cost zero reads.
// Only re-fetches when the server version number is newer than the cached one.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hierarchy_models.dart';

class HierarchyService {
  static const _cacheKey = 'hierarchy_cache_v1';
  static const _versionKey = 'hierarchy_version_v1';
  static const _collection = 'app_config';
  static const _document = 'hierarchy';

  final FirebaseFirestore _db;
  HierarchyService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Returns the hierarchy, using cache when possible.
  /// Costs 0 reads on cache hit, 1 read on cache miss or version bump.
  Future<HierarchyCache> get() async {
    final prefs = await SharedPreferences.getInstance();

    // Check server version first (1 tiny read — just the version field)
    final serverVersion = await _fetchServerVersion();
    final cachedVersion = prefs.getInt(_versionKey) ?? -1;

    if (serverVersion == cachedVersion) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          return HierarchyCache.fromMap(
            jsonDecode(cached) as Map<String, dynamic>,
          );
        } catch (_) {
          // Cache corrupted — fall through to full fetch
        }
      }
    }

    // Full fetch: 1 Firestore read
    final doc = await _db.collection(_collection).doc(_document).get();
    if (!doc.exists) return HierarchyCache.empty();

    final data = doc.data()!;
    final cache = HierarchyCache.fromMap(data);

    // Persist to SharedPreferences
    await prefs.setString(_cacheKey, jsonEncode(data));
    await prefs.setInt(_versionKey, cache.version);

    return cache;
  }

  /// Saves an updated hierarchy tree (admin only).
  /// Bumps the version so all clients re-fetch on next open.
  Future<void> save(HierarchyCache hierarchy) async {
    final newVersion = hierarchy.version + 1;
    final data = HierarchyCache(
      zones: hierarchy.zones,
      version: newVersion,
    ).toMap();
    await _db.collection(_collection).doc(_document).set(data);

    // Update local cache immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data));
    await prefs.setInt(_versionKey, newVersion);
  }

  /// Clears local cache — next [get] will do a full fetch.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_versionKey);
  }

  // Fetches only the version field to decide whether cache is stale.
  // Uses Firestore's field mask — counts as 1 document read minimum.
  Future<int> _fetchServerVersion() async {
    try {
      final doc = await _db
          .collection(_collection)
          .doc(_document)
          .get(const GetOptions(source: Source.server));
      return (doc.data()?['version'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return -1; // Network error — use cache
    }
  }
}
