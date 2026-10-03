import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_profile.dart';

class AuthService {
  final SupabaseClient _client;
  AuthService(this._client);

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserProfile?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _client
        .from('user_profiles')
        .select('id, tenant_id, full_name, employee_id, designation, phone, avatar_url, org_unit_id, org_units(name)')
        .eq('id', user.id)
        .single();

    final permissions = await _client.rpc('get_user_permissions', params: {
      'p_user_id': user.id,
      'p_org_unit_id': data['org_unit_id'],
    }) as List<dynamic>;

    return UserProfile(
      id:          data['id'] as String,
      tenantId:    data['tenant_id'] as String,
      fullName:    data['full_name'] as String,
      employeeId:  data['employee_id'] as String,
      designation: data['designation'] as String,
      phone:       data['phone'] as String?,
      avatarUrl:   data['avatar_url'] as String?,
      orgUnitId:   data['org_unit_id'] as String,
      orgUnitName: (data['org_units'] as Map<String, dynamic>)['name'] as String,
      permissions: permissions.cast<String>(),
    );
  }
}
