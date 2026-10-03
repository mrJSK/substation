import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../data/org_repository.dart';
import '../domain/org_models.dart';

final orgLevelsProvider = FutureProvider<List<OrgLevel>>((ref) {
  ref.watch(accessProfileProvider);
  return ref.watch(orgRepositoryProvider).levels();
});

/// Public to other features (pickers, breadcrumbs, scope labels).
final orgTreeProvider = FutureProvider<List<OrgUnit>>((ref) {
  ref.watch(accessProfileProvider);
  return ref.watch(orgRepositoryProvider).tree();
});

final orgUnitByIdProvider = Provider.family<OrgUnit?, String>((ref, id) {
  for (final unit in ref.watch(orgTreeProvider).value ?? const <OrgUnit>[]) {
    if (unit.id == id) return unit;
  }
  return null;
});

final orgSharesProvider = FutureProvider.autoDispose<List<OrgShare>>((ref) => ref.watch(orgRepositoryProvider).shares());
