import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../domain/access_profile.dart';

/// The signed-in user's access profile; null when signed out.
class SessionController extends AsyncNotifier<AccessProfile?> {
  @override
  Future<AccessProfile?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.authChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedOut && ref.mounted) state = const AsyncData(null);
    });
    ref.onDispose(sub.cancel);

    if (repo.userId == null) return null;
    return repo.loadAccess();
  }

  Future<void> signIn({required String email, required String password}) async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.signIn(email: email, password: password);
      try {
        return await repo.loadAccess();
      } catch (_) {
        await repo.signOut();
        rethrow;
      }
    });
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  /// Re-reads roles and permissions, e.g. after an administrator changed them.
  Future<void> reload() async {
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).loadAccess());
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, AccessProfile?>(SessionController.new);

/// Convenience: the current profile or null (never throws).
final accessProfileProvider = Provider<AccessProfile?>((ref) => ref.watch(sessionProvider).value);
