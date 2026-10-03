import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/access_profile.dart';

class AuthRepository {
  AuthRepository(this._client, this._cache);
  final SupabaseClient _client;
  final LocalCache _cache;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;
  String? get userId => _client.auth.currentUser?.id;

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() async {
    await _cache.clear();
    await _client.auth.signOut();
  }

  /// Fresh from the server when online; falls back to the device copy offline.
  Future<AccessProfile> loadAccess() async {
    final uid = userId;
    if (uid == null) throw const AppFailure('Not signed in.');
    final key = 'access:$uid';
    try {
      final data = await _client.rpc('get_my_access');
      if (data == null) {
        throw const AppFailure('Your account is not linked to an organisation yet. Contact your administrator.');
      }
      await _cache.write(key, data);
      return AccessProfile.fromJson((data as Map).cast<String, dynamic>());
    } on AppFailure {
      rethrow;
    } catch (e) {
      final cached = _cache.read(key, maxAge: AppConstants.accessCacheMaxAge);
      if (cached != null) return AccessProfile.fromJson((cached as Map).cast<String, dynamic>(), fromCache: true);
      throw AppFailure.from(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider), ref.watch(localCacheProvider)),
);
