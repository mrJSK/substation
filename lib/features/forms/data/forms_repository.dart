import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/form_schema.dart';

/// Dynamic UI data: form definitions and per-tenant micro-app settings.
class FormsRepository {
  FormsRepository(this._client, this._cache);
  final SupabaseClient _client;
  final LocalCache _cache;

  /// Effective form for a code (tenant override, else standard). Cached for offline use.
  Future<FormDefinition> form(String code) async {
    final key = 'form:$code:${_client.auth.currentUser?.id}';
    try {
      final data = await _client.rpc('get_form', params: {'p_code': code});
      if (data == null) throw AppFailure('Form $code is not defined.');
      await _cache.write(key, data);
      return FormDefinition.fromJson((data as Map).cast<String, dynamic>());
    } on AppFailure {
      rethrow;
    } catch (e) {
      final cached = _cache.read(key, maxAge: AppConstants.catalogCacheMaxAge);
      if (cached != null) return FormDefinition.fromJson((cached as Map).cast<String, dynamic>());
      throw AppFailure.from(e);
    }
  }

  /// All forms visible to the tenant (standard and overrides), newest version first.
  Future<List<FormDefinition>> allForms() async {
    final rows = await _client
        .from('ui_forms')
        .select('id, tenant_id, code, version, title, description, schema')
        .eq('is_active', true)
        .order('code', ascending: true)
        .order('version', ascending: false);
    return rows.map(FormDefinition.fromJson).toList();
  }

  /// Saves a tenant override as a new version (older versions stay for history).
  Future<void> saveOverride({required String tenantId, required FormDefinition base, required Map<String, dynamic> schema}) async {
    await _client.from('ui_forms').insert({
      'tenant_id': tenantId,
      'code': base.code,
      'version': base.version + 1,
      'title': base.title,
      'description': base.description,
      'schema': schema,
    });
  }

  Future<List<Map<String, dynamic>>> appCatalog() =>
      _client.from('app_catalog').select('code, name, module, required_permission').eq('is_active', true).order('code', ascending: true);

  Future<Map<String, bool>> appSettings() async {
    final rows = await _client.from('tenant_app_settings').select('app_code, is_enabled');
    return {for (final r in rows) r['app_code'] as String: r['is_enabled'] as bool};
  }

  Future<void> setAppEnabled({required String tenantId, required String appCode, required bool enabled}) =>
      _client.from('tenant_app_settings').upsert(
        {'tenant_id': tenantId, 'app_code': appCode, 'is_enabled': enabled},
        onConflict: 'tenant_id,app_code',
      );
}

final formsRepositoryProvider = Provider<FormsRepository>(
  (ref) => FormsRepository(ref.watch(supabaseClientProvider), ref.watch(localCacheProvider)),
);

/// Public to other features: effective form definition by code.
final formDefinitionProvider = FutureProvider.family<FormDefinition, String>((ref, code) => ref.watch(formsRepositoryProvider).form(code));
