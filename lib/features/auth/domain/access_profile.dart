import '../../../core/json.dart';

/// Everything the app needs to authorise the signed-in user, from one
/// get_my_access() call. Evaluated locally, so permission checks work offline.
/// The database enforces the same rules again on every request.
class AccessProfile {
  const AccessProfile({
    required this.userId,
    required this.fullName,
    required this.tenantId,
    required this.tenantName,
    required this.grants,
    this.email,
    this.designation,
    this.employeeId,
    this.homeOrgUnitId,
    this.fromCache = false,
  });

  final String userId;
  final String fullName;
  final String? email;
  final String? designation;
  final String? employeeId;
  final String? homeOrgUnitId;
  final String tenantId;
  final String tenantName;
  final List<RoleGrant> grants;
  final bool fromCache;

  factory AccessProfile.fromJson(Map<String, dynamic> json, {bool fromCache = false}) {
    final profile = json.mapOrNull('profile')!;
    final tenant = json.mapOrNull('tenant')!;
    return AccessProfile(
      userId: profile.str('id'),
      fullName: profile.str('full_name'),
      email: profile.strOrNull('email'),
      designation: profile.strOrNull('designation'),
      employeeId: profile.strOrNull('employee_id'),
      homeOrgUnitId: profile.strOrNull('home_org_unit_id'),
      tenantId: tenant.str('id'),
      tenantName: tenant.str('name'),
      grants: json.mapList('assignments').map(RoleGrant.fromJson).toList(),
      fromCache: fromCache,
    );
  }

  /// Holds [code] at any scope (decides whether a micro-app is offered).
  bool canAnywhere(String code) => grants.any((g) => g.permissions.contains(code));

  /// Holds [code] at the unit with materialized path [unitPath].
  bool can(String code, {required String unitPath}) =>
      grants.any((g) => g.permissions.contains(code) && g.covers(unitPath));

  /// Holds [code] tenant-wide (granted at a root unit including descendants).
  bool canTenantWide(String code) =>
      grants.any((g) => g.permissions.contains(code) && g.includeDescendants && !g.scopePath.contains('.'));
}

/// One role held at one scope: the WHO × WHAT × WHERE triple.
class RoleGrant {
  const RoleGrant({
    required this.roleCode,
    required this.roleName,
    required this.orgUnitId,
    required this.orgUnitName,
    required this.scopePath,
    required this.includeDescendants,
    required this.permissions,
  });

  final String roleCode;
  final String roleName;
  final String orgUnitId;
  final String orgUnitName;
  final String scopePath;
  final bool includeDescendants;
  final Set<String> permissions;

  factory RoleGrant.fromJson(Map<String, dynamic> json) => RoleGrant(
        roleCode: json.str('role_code'),
        roleName: json.str('role_name'),
        orgUnitId: json.str('org_unit_id'),
        orgUnitName: json.str('org_unit_name'),
        scopePath: json.str('scope_path'),
        includeDescendants: json.boolOr('include_descendants', true),
        permissions: ((json['permissions'] as List?) ?? const []).cast<String>().toSet(),
      );

  bool covers(String unitPath) =>
      unitPath == scopePath || (includeDescendants && unitPath.startsWith('$scopePath.'));
}
