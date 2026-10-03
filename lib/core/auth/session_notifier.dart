import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../../shared/models/user_profile.dart';

part 'session_notifier.g.dart';

@riverpod
AuthService authService(Ref ref) =>
    AuthService(Supabase.instance.client);

// Watches Supabase auth state — null = signed out, non-null = signed in
@riverpod
Stream<User?> authUser(Ref ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateChanges.map((s) => s.session?.user);
}

// Fetched once on login; invalidated on sign-out
@riverpod
class SessionNotifier extends _$SessionNotifier {
  @override
  Future<UserProfile?> build() async {
    final service = ref.watch(authServiceProvider);
    if (!service.isAuthenticated) return null;

    // Re-fetch when auth state changes
    ref.listen(authUserProvider, (_, next) {
      next.whenData((user) {
        if (user == null) state = const AsyncData(null);
        else ref.invalidateSelf();
      });
    });

    return service.fetchProfile();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final service = ref.read(authServiceProvider);
    try {
      await service.signIn(email: email, password: password);
      final profile = await service.fetchProfile();
      state = AsyncData(profile);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    state = const AsyncData(null);
  }
}
