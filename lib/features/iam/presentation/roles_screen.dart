import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../application/iam_providers.dart';
import '../data/iam_repository.dart';
import '../domain/iam_models.dart';

/// PFCG — Role Maintenance.
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final canEdit = ref.watch(accessProfileProvider)?.canTenantWide('ROLE_ADMIN') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles'),
        actions: [
          if (canEdit) TextButton(onPressed: () => showSheet(context, const _RoleForm()), child: const Text('New role')),
        ],
      ),
      body: AsyncValueView(
        value: roles,
        onRetry: () => ref.invalidate(rolesProvider),
        data: (list) {
          final custom = list.where((r) => !r.isTemplate).toList();
          final templates = list.where((r) => r.isTemplate).toList();
          return ListView(
            children: [
              const SectionLabel('Your roles'),
              if (custom.isEmpty)
                const EmptyState('No custom roles yet. Copy a standard role to adapt it.'),
              for (final r in custom) _roleTile(context, r),
              const SectionLabel('Standard roles'),
              for (final r in templates) _roleTile(context, r),
            ],
          );
        },
      ),
    );
  }

  Widget _roleTile(BuildContext context, Role r) => Column(
        children: [
          ListTile(
            dense: true,
            title: Text(r.name),
            subtitle: Text([r.code, if (r.description != null) r.description!].join(' · ')),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoleDetailScreen(role: r))),
          ),
          const Divider(height: 1),
        ],
      );
}

/// Permission matrix of one role (the WHAT axis).
class RoleDetailScreen extends ConsumerWidget {
  const RoleDetailScreen({super.key, required this.role});
  final Role role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(permissionCatalogProvider);
    final granted = ref.watch(rolePermissionsProvider(role.id));
    final canEdit = !role.isTemplate && (ref.watch(accessProfileProvider)?.canTenantWide('ROLE_ADMIN') ?? false);
    final canCopy = ref.watch(accessProfileProvider)?.canTenantWide('ROLE_ADMIN') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(role.name),
        actions: [
          if (canCopy) TextButton(onPressed: () => showSheet(context, _RoleForm(copyFrom: role)), child: const Text('Copy')),
          if (canEdit)
            TextButton(
              onPressed: () async {
                final yes = await confirm(context,
                    title: 'Delete ${role.name}?', message: 'Users holding this role lose it immediately.', action: 'Delete');
                if (!yes || !context.mounted) return;
                final ok = await runWithFeedback(context, () => ref.read(iamRepositoryProvider).deleteRole(role.id));
                if (ok && context.mounted) {
                  ref.invalidate(rolesProvider);
                  Navigator.pop(context);
                }
              },
              child: const Text('Delete'),
            ),
        ],
      ),
      body: AsyncValueView(
        value: catalog,
        onRetry: () => ref.invalidate(permissionCatalogProvider),
        data: (perms) => AsyncValueView(
          value: granted,
          onRetry: () => ref.invalidate(rolePermissionsProvider(role.id)),
          data: (codes) {
            final byModule = <String, List<Permission>>{};
            for (final p in perms) {
              byModule.putIfAbsent(p.module, () => []).add(p);
            }
            return ListView(
              children: [
                if (role.isTemplate)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text('Standard roles are read-only. Use Copy to create an editable version.'),
                  ),
                for (final entry in byModule.entries) ...[
                  SectionLabel(entry.key),
                  for (final p in entry.value)
                    CheckboxListTile(
                      dense: true,
                      value: codes.contains(p.code),
                      title: Text(p.description),
                      subtitle: Text(p.code),
                      onChanged: canEdit
                          ? (v) async {
                              final ok = await runWithFeedback(context,
                                  () => ref.read(iamRepositoryProvider).setRolePermission(role.id, p.code, granted: v ?? false));
                              if (ok) ref.invalidate(rolePermissionsProvider(role.id));
                            }
                          : null,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoleForm extends ConsumerStatefulWidget {
  const _RoleForm({this.copyFrom});
  final Role? copyFrom;

  @override
  ConsumerState<_RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends ConsumerState<_RoleForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.copyFrom == null ? '' : 'Z_${widget.copyFrom!.code}');
  late final _name = TextEditingController(text: widget.copyFrom?.name);
  final _description = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(iamRepositoryProvider);
    final code = _code.text.trim().toUpperCase();
    final name = _name.text.trim();
    final ok = await runWithFeedback(context, () async {
      if (widget.copyFrom != null) {
        await repo.cloneRole(sourceRoleId: widget.copyFrom!.id, code: code, name: name);
      } else {
        await repo.createRole(
          tenantId: ref.read(accessProfileProvider)!.tenantId,
          code: code,
          name: name,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        );
      }
    });
    if (ok && mounted) {
      ref.invalidate(rolesProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.copyFrom == null ? 'New role' : 'Copy ${widget.copyFrom!.name}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code', isDense: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name', isDense: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          if (widget.copyFrom == null) ...[
            const SizedBox(height: 8),
            TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description', isDense: true)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
