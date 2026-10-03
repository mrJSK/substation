import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/iam_repository.dart';
import '../domain/iam_models.dart';

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) => ref.watch(iamRepositoryProvider).users());

final userProvider = FutureProvider.autoDispose.family<AppUser, String>((ref, id) => ref.watch(iamRepositoryProvider).user(id));

final userAssignmentsProvider = FutureProvider.autoDispose.family<List<RoleAssignment>, String>(
  (ref, userId) => ref.watch(iamRepositoryProvider).assignmentsOfUser(userId),
);

final rolesProvider = FutureProvider.autoDispose<List<Role>>((ref) => ref.watch(iamRepositoryProvider).roles());

final permissionCatalogProvider = FutureProvider<List<Permission>>((ref) => ref.watch(iamRepositoryProvider).permissions());

final rolePermissionsProvider = FutureProvider.autoDispose.family<Set<String>, String>(
  (ref, roleId) => ref.watch(iamRepositoryProvider).rolePermissionCodes(roleId),
);
