import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../data/app_catalog_repository.dart';
import '../domain/micro_app.dart';

/// Re-evaluated whenever the session changes (sign-in, role reload).
final myAppsProvider = FutureProvider<List<MicroApp>>((ref) async {
  final profile = ref.watch(accessProfileProvider);
  if (profile == null) return const [];
  return ref.watch(appCatalogRepositoryProvider).myApps();
});

final myAppByCodeProvider = Provider.family<MicroApp?, String>((ref, code) {
  final apps = ref.watch(myAppsProvider).value ?? const [];
  for (final app in apps) {
    if (app.code == code) return app;
  }
  return null;
});
