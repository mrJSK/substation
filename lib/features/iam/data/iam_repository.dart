import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/json.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/iam_models.dart';

/// All IAM data access. RLS and the database guards enforce every rule;
/// this class only shapes requests and responses.
class IamRepository {
  IamRepository(this._client);
  final SupabaseClient _client;

  static const _userColumns = 'id, full_name, email, employee_id, designation, phone, home_org_unit_id, is_active, valid_to';

  // ── Users ───────────────────────────────────────────────────────────────
  Future<List<AppUser>> users() async {
    final rows = await _client.from('user_profiles').select(_userColumns).order('full_name', ascending: true);
    return rows.map(AppUser.fromJson).toList();
  }

  Future<AppUser> user(String id) async =>
      AppUser.fromJson(await _client.from('user_profiles').select(_userColumns).eq('id', id).single());

  /// Creates the sign-in account and profile server-side (Edge Function).
  Future<String> createUser({
    required String email,
    required String temporaryPassword,
    required String fullName,
    required String homeOrgUnitId,
    String? employeeId,
    String? designation,
    String? phone,
    String? roleId,
  }) async {
    final res = await _client.functions.invoke('iam-admin-users', body: {
      'email': email,
      'password': temporaryPassword,
      'full_name': fullName,
      'home_org_unit_id': homeOrgUnitId,
      'employee_id': employeeId,
      'designation': designation,
      'phone': phone,
      'role_id': roleId,
    });
    final data = (res.data as Map).cast<String, dynamic>();
    return data['user_id'] as String;
  }

  Future<void> updateUser(String id, {String? fullName, String? employeeId, String? designation, String? phone,
      String? homeOrgUnitId, bool? isActive}) async {
    await _client.from('user_profiles').update({
      'full_name': ?fullName,
      'employee_id': ?employeeId,
      'designation': ?designation,
      'phone': ?phone,
      'home_org_unit_id': ?homeOrgUnitId,
      'is_active': ?isActive,
    }).eq('id', id);
  }

  // ── Roles and permissions ───────────────────────────────────────────────
  Future<List<Role>> roles() async {
    final rows = await _client.from('roles').select('id, tenant_id, code, name, description').order('name', ascending: true);
    return rows.map(Role.fromJson).toList();
  }

  Future<List<Permission>> permissions() async {
    final rows = await _client.from('permissions').select('code, module, description').order('sort_order', ascending: true);
    return rows.map(Permission.fromJson).toList();
  }

  Future<Set<String>> rolePermissionCodes(String roleId) async {
    final rows = await _client.from('role_permissions').select('permission_code').eq('role_id', roleId);
    return rows.map((r) => r['permission_code'] as String).toSet();
  }

  Future<void> setRolePermission(String roleId, String code, {required bool granted}) async {
    if (granted) {
      await _client.from('role_permissions').insert({'role_id': roleId, 'permission_code': code});
    } else {
      await _client.from('role_permissions').delete().eq('role_id', roleId).eq('permission_code', code);
    }
  }

  Future<void> createRole({required String tenantId, required String code, required String name, String? description}) =>
      _client.from('roles').insert({'tenant_id': tenantId, 'code': code, 'name': name, 'description': description});

  Future<String> cloneRole({required String sourceRoleId, required String code, required String name}) async =>
      await _client.rpc('clone_role', params: {'p_source_role_id': sourceRoleId, 'p_code': code, 'p_name': name}) as String;

  Future<void> deleteRole(String id) => _client.from('roles').delete().eq('id', id);

  // ── Assignments (WHERE) ─────────────────────────────────────────────────
  Future<List<RoleAssignment>> assignmentsOfUser(String userId) async {
    final rows = await _client
        .from('user_role_assignments')
        .select('id, user_id, role_id, org_unit_id, include_descendants, valid_from, valid_to, roles(name)')
        .eq('user_id', userId)
        .order('valid_from', ascending: false);
    return rows.map(RoleAssignment.fromJson).toList();
  }

  Future<void> assignRole({
    required String tenantId,
    required String userId,
    required String roleId,
    required String orgUnitId,
    required bool includeDescendants,
    required DateTime validFrom,
    DateTime? validTo,
  }) async {
    await _client.from('user_role_assignments').insert({
      'tenant_id': tenantId,
      'user_id': userId,
      'role_id': roleId,
      'org_unit_id': orgUnitId,
      'include_descendants': includeDescendants,
      'valid_from': isoDate(validFrom),
      'valid_to': validTo == null ? null : isoDate(validTo),
    });
  }

  Future<void> revokeAssignment(String id) => _client.from('user_role_assignments').delete().eq('id', id);
}

final iamRepositoryProvider = Provider<IamRepository>((ref) => IamRepository(ref.watch(supabaseClientProvider)));
