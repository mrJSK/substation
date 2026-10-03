import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/iam_repository.dart';

part 'users_screen.g.dart';

@riverpod
IamRepository iamRepository(Ref ref) =>
    IamRepository(Supabase.instance.client);

@riverpod
Future<List<Map<String, dynamic>>> userList(Ref ref) =>
    ref.watch(iamRepositoryProvider).listUsers();

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(userListProvider),
          ),
        ],
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No users found.'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = list[i];
                  final orgUnit = u['org_units'] as Map<String, dynamic>?;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        (u['full_name'] as String? ?? '?').characters.first.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Text(u['full_name'] as String? ?? '—'),
                    subtitle: Text(
                      '${u['designation'] ?? ''} — ${orgUnit?['name'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      u['employee_id'] as String? ?? '',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    onTap: () => _showUserDetail(context, ref, u['id'] as String),
                  );
                },
              ),
      ),
    );
  }

  void _showUserDetail(BuildContext context, WidgetRef ref, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(userId: userId)),
    );
  }
}

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(iamRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('User Detail')),
      body: FutureBuilder(
        future: Future.wait<dynamic>([
          repo.getUser(userId),
          repo.getUserRoleAssignments(userId),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));

          final user   = snapshot.data![0] as Map<String, dynamic>;
          final roles  = snapshot.data![1] as List<Map<String, dynamic>>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User info card
              _InfoRow('Name',        user['full_name'] as String? ?? '—'),
              _InfoRow('Employee ID', user['employee_id'] as String? ?? '—'),
              _InfoRow('Designation', user['designation'] as String? ?? '—'),
              _InfoRow('Phone',       user['phone'] as String? ?? '—'),
              _InfoRow('Org Unit',    (user['org_units'] as Map?)?.get('name') ?? '—'),

              const Divider(height: 32),

              // Role assignments — Where × What
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Role Assignments',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: () => _addRole(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (roles.isEmpty)
                const Text('No roles assigned.', style: TextStyle(color: Color(0xFF6B7280)))
              else
                ...roles.map((r) {
                  final role    = r['roles']    as Map<String, dynamic>?;
                  final orgUnit = r['org_units'] as Map<String, dynamic>?;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(role?['name'] as String? ?? '—'),
                    subtitle: Text(
                      'Scope: ${orgUnit?['name'] ?? '—'}'
                      '${r['valid_to'] != null ? '  Until: ${r['valid_to']}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                      onPressed: () async {
                        await repo.revokeRoleAssignment(r['id'] as String);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  void _addRole(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignRoleSheet(userId: userId, ref: ref),
    );
  }
}

class _AssignRoleSheet extends ConsumerStatefulWidget {
  const _AssignRoleSheet({required this.userId, required this.ref});
  final String userId;
  final WidgetRef ref;

  @override
  ConsumerState<_AssignRoleSheet> createState() => _AssignRoleSheetState();
}

class _AssignRoleSheetState extends ConsumerState<_AssignRoleSheet> {
  String? _selectedRole;
  String? _selectedOrgUnit;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final repo = widget.ref.watch(iamRepositoryProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16,
          MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Assign Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),

          // WHO: Role picker
          FutureBuilder(
            future: repo.listRoles(),
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              final roles = snap.data!;
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Role (What)'),
                value: _selectedRole,
                items: roles.map((r) => DropdownMenuItem<String>(
                  value: r['id'] as String,
                  child: Text(r['name'] as String),
                )).toList(),
                onChanged: (v) => setState(() => _selectedRole = v),
              );
            },
          ),
          const SizedBox(height: 12),

          // WHERE: Org unit picker
          FutureBuilder(
            future: repo.listOrgUnits(),
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              final units = snap.data!;
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Scope (Where)'),
                value: _selectedOrgUnit,
                isExpanded: true,
                items: units.map((u) => DropdownMenuItem<String>(
                  value: u['id'] as String,
                  child: Text('${u['name']} (L${u['level']})', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) => setState(() => _selectedOrgUnit = v),
              );
            },
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: (_selectedRole == null || _selectedOrgUnit == null || _saving)
                ? null
                : () async {
                    setState(() => _saving = true);
                    await repo.assignRole(
                      userId:    widget.userId,
                      roleId:    _selectedRole!,
                      orgUnitId: _selectedOrgUnit!,
                    );
                    if (mounted) Navigator.pop(context);
                  },
            child: _saving
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Assign'),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text(label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

extension on Map {
  dynamic get(String key) => this[key];
}
