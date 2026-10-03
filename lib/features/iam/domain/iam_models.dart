import '../../../core/json.dart';

/// WHO: a person who can sign in.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.isActive,
    this.email,
    this.employeeId,
    this.designation,
    this.phone,
    this.homeOrgUnitId,
    this.validTo,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? employeeId;
  final String? designation;
  final String? phone;
  final String? homeOrgUnitId;
  final bool isActive;
  final DateTime? validTo;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j.str('id'),
        fullName: j.str('full_name'),
        email: j.strOrNull('email'),
        employeeId: j.strOrNull('employee_id'),
        designation: j.strOrNull('designation'),
        phone: j.strOrNull('phone'),
        homeOrgUnitId: j.strOrNull('home_org_unit_id'),
        isActive: j.boolOr('is_active', true),
        validTo: j.dateOrNull('valid_to'),
      );
}

/// WHAT: one permission code from the catalog.
class Permission {
  const Permission({required this.code, required this.module, required this.description});
  final String code;
  final String module;
  final String description;

  factory Permission.fromJson(Map<String, dynamic> j) =>
      Permission(code: j.str('code'), module: j.str('module'), description: j.str('description'));
}

/// A bundle of permissions. Templates (tenantId == null) are read-only.
class Role {
  const Role({required this.id, required this.code, required this.name, this.tenantId, this.description});
  final String id;
  final String? tenantId;
  final String code;
  final String name;
  final String? description;

  bool get isTemplate => tenantId == null;

  factory Role.fromJson(Map<String, dynamic> j) => Role(
        id: j.str('id'),
        tenantId: j.strOrNull('tenant_id'),
        code: j.str('code'),
        name: j.str('name'),
        description: j.strOrNull('description'),
      );
}

/// WHO has WHICH role WHERE, and for how long.
class RoleAssignment {
  const RoleAssignment({
    required this.id,
    required this.userId,
    required this.roleId,
    required this.roleName,
    required this.orgUnitId,
    required this.includeDescendants,
    required this.validFrom,
    this.validTo,
  });

  final String id;
  final String userId;
  final String roleId;
  final String roleName;
  final String orgUnitId;
  final bool includeDescendants;
  final DateTime validFrom;
  final DateTime? validTo;

  bool get isExpired => validTo != null && validTo!.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  factory RoleAssignment.fromJson(Map<String, dynamic> j) => RoleAssignment(
        id: j.str('id'),
        userId: j.str('user_id'),
        roleId: j.str('role_id'),
        roleName: j.mapOrNull('roles')?.strOrNull('name') ?? '',
        orgUnitId: j.str('org_unit_id'),
        includeDescendants: j.boolOr('include_descendants', true),
        validFrom: j.dateOrNull('valid_from')!,
        validTo: j.dateOrNull('valid_to'),
      );
}
