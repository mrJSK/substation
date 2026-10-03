import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/json.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/org_models.dart';

class OrgRepository {
  OrgRepository(this._client, this._cache);
  final SupabaseClient _client;
  final LocalCache _cache;

  static const _treeColumns =
      'id, parent_id, name, code, path, depth, level_id, level_name, level_rank, is_operational, is_active, voltage_kv, total_consumers';

  // ── Levels ──────────────────────────────────────────────────────────────
  Future<List<OrgLevel>> levels() async {
    final rows = await _client.from('org_levels').select('id, rank, name, code, is_operational').order('rank', ascending: true);
    return rows.map(OrgLevel.fromJson).toList();
  }

  Future<void> saveLevel({String? id, required String tenantId, required int rank, required String name,
      required String code, required bool isOperational}) async {
    final values = {'rank': rank, 'name': name, 'code': code, 'is_operational': isOperational};
    if (id == null) {
      await _client.from('org_levels').insert({...values, 'tenant_id': tenantId});
    } else {
      await _client.from('org_levels').update(values).eq('id', id);
    }
  }

  Future<void> deleteLevel(String id) => _client.from('org_levels').delete().eq('id', id);

  // ── Units ───────────────────────────────────────────────────────────────
  /// Whole tree of the tenant, ordered by path. Cached for offline pickers.
  Future<List<OrgUnit>> tree() async {
    final key = 'org_tree:${_client.auth.currentUser?.id}';
    try {
      final rows = await _client.from('org_tree').select(_treeColumns).order('path', ascending: true);
      await _cache.write(key, rows);
      return rows.map(OrgUnit.fromJson).toList();
    } catch (e) {
      final cached = _cache.read(key, maxAge: AppConstants.orgTreeCacheMaxAge) as List?;
      if (cached != null) return cached.map((r) => OrgUnit.fromJson((r as Map).cast<String, dynamic>())).toList();
      throw AppFailure.from(e);
    }
  }

  Future<void> createUnit({required String tenantId, required String? parentId, required String levelId,
      required String name, required String code, double? voltageKv, int totalConsumers = 0}) async {
    await _client.from('org_units').insert({
      'tenant_id': tenantId, 'parent_id': parentId, 'level_id': levelId, 'name': name, 'code': code,
      'voltage_kv': voltageKv, 'total_consumers': totalConsumers,
    });
  }

  Future<void> updateUnit(String id, {required String? parentId, required String levelId, required String name,
      required String code, double? voltageKv, required int totalConsumers, required bool isActive}) async {
    await _client.from('org_units').update({
      'parent_id': parentId, 'level_id': levelId, 'name': name, 'code': code,
      'voltage_kv': voltageKv, 'total_consumers': totalConsumers, 'is_active': isActive,
    }).eq('id', id);
  }

  Future<void> deleteUnit(String id) => _client.from('org_units').delete().eq('id', id);

  // ── Cross-level sharing ─────────────────────────────────────────────────
  Future<List<OrgShare>> shares() async {
    final rows = await _client
        .from('org_unit_shares')
        .select('id, source_org_unit_id, target_org_unit_id, valid_from, valid_to, reason')
        .order('created_at', ascending: false);
    return rows.map(OrgShare.fromJson).toList();
  }

  Future<void> createShare({required String tenantId, required String sourceId, required String targetId,
      DateTime? validTo, String? reason}) async {
    await _client.from('org_unit_shares').insert({
      'tenant_id': tenantId, 'source_org_unit_id': sourceId, 'target_org_unit_id': targetId,
      'valid_to': validTo == null ? null : isoDate(validTo), 'reason': reason,
    });
  }

  Future<void> deleteShare(String id) => _client.from('org_unit_shares').delete().eq('id', id);
}

final orgRepositoryProvider = Provider<OrgRepository>(
  (ref) => OrgRepository(ref.watch(supabaseClientProvider), ref.watch(localCacheProvider)),
);
