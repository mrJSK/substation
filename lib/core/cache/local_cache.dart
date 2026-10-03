import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Small JSON cache with per-entry age, backed by Hive (IndexedDB on web).
/// Used to keep reference data on the device so the app works offline and
/// avoids re-downloading it every shift.
class LocalCache {
  LocalCache(this._box);
  final Box<String> _box;

  static const boxName = 'grid_cache';

  static Future<LocalCache> open() async {
    await Hive.initFlutter();
    return LocalCache(await Hive.openBox<String>(boxName));
  }

  Future<void> write(String key, Object? data) =>
      _box.put(key, jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'data': data}));

  /// Returns the cached value, or null when missing or older than [maxAge].
  dynamic read(String key, {required Duration maxAge}) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final at = DateTime.fromMillisecondsSinceEpoch(entry['at'] as int);
    if (DateTime.now().difference(at) > maxAge) return null;
    return entry['data'];
  }

  Future<void> clear() => _box.clear();
}

/// Overridden in main() with the opened cache.
final localCacheProvider = Provider<LocalCache>((ref) => throw UnimplementedError('LocalCache not initialised'));
