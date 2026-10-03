import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'users_screen.dart';

part 'roles_screen.g.dart';

@riverpod
Future<List<Map<String, dynamic>>> roleList(Ref ref) =>
    ref.watch(iamRepositoryProvider).listRoles();

@riverpod
Future<List<Map<String, dynamic>>> permissionList(Ref ref) =>
    ref.watch(iamRepositoryProvider).listPermissions();

class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(roleListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Roles & Permissions')),
      body: roles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = list[i];
            return ListTile(
              title: Text(r['name'] as String),
              subtitle: Text(r['description'] as String? ?? '',
                  style: const TextStyle(fontSize: 12)),
              trailing: r['is_system'] == true
                  ? const Chip(label: Text('System', style: TextStyle(fontSize: 11)))
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoleDetailScreen(
                    roleId: r['id'] as String,
                    roleName: r['name'] as String,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shows the permission matrix for a single role — the "What" axis.
class RoleDetailScreen extends ConsumerWidget {
  const RoleDetailScreen({super.key, required this.roleId, required this.roleName});
  final String roleId, roleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(iamRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(roleName)),
      body: FutureBuilder(
        future: Future.wait<dynamic>([
          repo.getRolePermissions(roleId),
          repo.listPermissions(),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final assigned   = snap.data![0] as List<Map<String, dynamic>>;
          final allPerms   = snap.data![1] as List<Map<String, dynamic>>;
          final assignedIds = assigned
              .map((a) => (a['permissions'] as Map<String, dynamic>?)?['code'])
              .toSet();

          // Group by module
          final byModule = <String, List<Map<String, dynamic>>>{};
          for (final p in allPerms) {
            final mod = p['module'] as String? ?? 'Other';
            byModule.putIfAbsent(mod, () => []).add(p);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: byModule.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(entry.key,
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280), letterSpacing: 0.8)),
                ),
                ...entry.value.map((p) {
                  final code = p['code'] as String;
                  final has  = assignedIds.contains(code);
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      has ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: has ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                      size: 20,
                    ),
                    title: Text(code, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                    subtitle: Text(p['description'] as String? ?? '',
                        style: const TextStyle(fontSize: 11)),
                  );
                }),
                const Divider(height: 1),
              ],
            )).toList(),
          );
        },
      ),
    );
  }
}
