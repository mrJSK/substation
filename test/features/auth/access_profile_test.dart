import 'package:flutter_test/flutter_test.dart';
import 'package:suberp/features/auth/domain/access_profile.dart';

void main() {
  // Tree: root(zone) > circle > substation ; second branch: root > circle2
  const root = 'aaa';
  const circle = 'aaa.bbb';
  const substation = 'aaa.bbb.ccc';
  const circle2 = 'aaa.ddd';

  AccessProfile profileWith(List<RoleGrant> grants) => AccessProfile(
        userId: 'u1',
        fullName: 'Test User',
        tenantId: 't1',
        tenantName: 'Utility',
        grants: grants,
      );

  RoleGrant grant(String path, Set<String> perms, {bool descendants = true}) => RoleGrant(
        roleCode: 'R',
        roleName: 'Role',
        orgUnitId: path,
        orgUnitName: path,
        scopePath: path,
        includeDescendants: descendants,
        permissions: perms,
      );

  test('a role at a circle covers the circle and everything below it', () {
    final p = profileWith([grant(circle, {'PTW_ISSUE'})]);
    expect(p.can('PTW_ISSUE', unitPath: circle), isTrue);
    expect(p.can('PTW_ISSUE', unitPath: substation), isTrue);
    expect(p.can('PTW_ISSUE', unitPath: root), isFalse, reason: 'scope never flows upwards');
    expect(p.can('PTW_ISSUE', unitPath: circle2), isFalse, reason: 'sibling branch is outside scope');
  });

  test('a role without descendants covers only its own unit', () {
    final p = profileWith([grant(circle, {'LOGSHEET_WRITE'}, descendants: false)]);
    expect(p.can('LOGSHEET_WRITE', unitPath: circle), isTrue);
    expect(p.can('LOGSHEET_WRITE', unitPath: substation), isFalse);
  });

  test('path prefixes do not leak into units with similar ids', () {
    final p = profileWith([grant('aaa.bb', {'X'})]);
    expect(p.can('X', unitPath: 'aaa.bbb'), isFalse);
  });

  test('tenant-wide means held at a root unit including descendants', () {
    expect(profileWith([grant(root, {'ROLE_ADMIN'})]).canTenantWide('ROLE_ADMIN'), isTrue);
    expect(profileWith([grant(circle, {'ROLE_ADMIN'})]).canTenantWide('ROLE_ADMIN'), isFalse);
    expect(profileWith([grant(root, {'ROLE_ADMIN'}, descendants: false)]).canTenantWide('ROLE_ADMIN'), isFalse);
  });

  test('parses the get_my_access payload', () {
    final p = AccessProfile.fromJson({
      'profile': {'id': 'u1', 'full_name': 'A B', 'email': 'a@b.c', 'home_org_unit_id': null},
      'tenant': {'id': 't1', 'name': 'UPPTCL', 'short_code': 'UP'},
      'assignments': [
        {
          'role_code': 'SHIFT_ENGINEER', 'role_name': 'Shift Engineer', 'org_unit_id': 'x', 'org_unit_name': 'SS',
          'scope_path': substation, 'include_descendants': true, 'permissions': ['PTW_ISSUE', 'LOGSHEET_WRITE'],
        },
      ],
      'issued_at': '2026-10-03T00:00:00Z',
    });
    expect(p.tenantName, 'UPPTCL');
    expect(p.canAnywhere('PTW_ISSUE'), isTrue);
    expect(p.canAnywhere('USER_ADMIN'), isFalse);
  });
}
