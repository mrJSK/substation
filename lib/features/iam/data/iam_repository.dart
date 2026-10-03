import 'package:supabase_flutter/supabase_flutter.dart';

/// IAM data layer — owned by the IAM team.
/// All Supabase calls for users, roles, and permission assignments live here.
/// No Riverpod here — pure data access. Notifiers in presentation/ wire it up.
class IamRepository {
  IamRepository(this._client);
  final SupabaseClient _client;

  // ── Users ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listUsers() async {
    final data = await _client
        .from('user_profiles')
        .select('id, full_name, employee_id, designation, phone, org_unit_id, org_units(name, level)')
        .order('full_name');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> getUser(String userId) async {
    return await _client
        .from('user_profiles')
        .select('id, full_name, employee_id, designation, phone, org_unit_id, org_units(name)')
        .eq('id', userId)
        .single() as Map<String, dynamic>;
  }

  Future<void> updateUser(String userId, Map<String, dynamic> fields) async {
    await _client.from('user_profiles').update(fields).eq('id', userId);
  }

  // ── Roles ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listRoles() async {
    final data = await _client
        .from('roles')
        .select('id, name, description, is_system')
        .order('name');
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ── Role assignments ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUserRoleAssignments(String userId) async {
    final data = await _client
        .from('user_role_assignments')
        .select('id, role_id, org_unit_id, valid_from, valid_to, roles(name, description), org_units(name, level)')
        .eq('user_id', userId)
        .order('valid_from');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> assignRole({
    required String userId,
    required String roleId,
    required String orgUnitId,
    DateTime? validFrom,
    DateTime? validTo,
  }) async {
    await _client.from('user_role_assignments').insert({
      'user_id':    userId,
      'role_id':    roleId,
      'org_unit_id': orgUnitId,
      'valid_from': (validFrom ?? DateTime.now()).toIso8601String().split('T')[0],
      if (validTo != null) 'valid_to': validTo.toIso8601String().split('T')[0],
    });
  }

  Future<void> revokeRoleAssignment(String assignmentId) async {
    await _client.from('user_role_assignments').delete().eq('id', assignmentId);
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listPermissions() async {
    final data = await _client
        .from('permissions')
        .select('id, code, description, module')
        .order('module, code');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> getRolePermissions(String roleId) async {
    final data = await _client
        .from('role_permissions')
        .select('id, permission_id, permissions(code, description, module)')
        .eq('role_id', roleId);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ── Org units (for scope pickers) ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listOrgUnits() async {
    final data = await _client
        .from('org_units')
        .select('id, name, code, level, parent_id')
        .eq('is_active', true)
        .order('level, name');
    return List<Map<String, dynamic>>.from(data as List);
  }
}
