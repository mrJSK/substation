import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/micro_app.dart';

class AppCatalogRepository {
  AppCatalogRepository(this._client, this._cache);
  final SupabaseClient _client;
  final LocalCache _cache;

  /// Apps the user may launch. Cached per user; refreshed when online.
  Future<List<MicroApp>> myApps() async {
    final key = 'apps:${_client.auth.currentUser?.id}';
    try {
      final data = await _client.rpc('get_my_apps') as List;
      await _cache.write(key, data);
      return data.map((e) => MicroApp.fromJson((e as Map).cast<String, dynamic>())).toList();
    } catch (e) {
      final cached = _cache.read(key, maxAge: AppConstants.catalogCacheMaxAge) as List?;
      if (cached != null) return cached.map((e) => MicroApp.fromJson((e as Map).cast<String, dynamic>())).toList();
      throw AppFailure.from(e);
    }
  }
}

final appCatalogRepositoryProvider = Provider<AppCatalogRepository>(
  (ref) => AppCatalogRepository(ref.watch(supabaseClientProvider), ref.watch(localCacheProvider)),
);
