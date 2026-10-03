import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../../org/application/org_providers.dart';
import '../../org/presentation/org_unit_picker.dart';
import '../application/iam_providers.dart';
import '../data/iam_repository.dart';
import '../domain/iam_models.dart';

/// One user: profile, active state and role assignments (WHO × WHAT × WHERE).
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(userId));
    final assignments = ref.watch(userAssignmentsProvider(userId));
    final profile = ref.watch(accessProfileProvider);
    final canAdmin = profile?.canAnywhere('USER_ADMIN') ?? false;
    final dates = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(user.value?.fullName ?? 'User')),
      body: AsyncValueView(
        value: user,
        onRetry: () => ref.invalidate(userProvider(userId)),
        data: (u) => ListView(
          children: [
            _info(context, 'Email', u.email),
            _info(context, 'Employee ID', u.employeeId),
            _info(context, 'Designation', u.designation),
            _info(context, 'Phone', u.phone),
            _info(context, 'Home unit', u.homeOrgUnitId == null ? null : ref.watch(orgUnitByIdProvider(u.homeOrgUnitId!))?.name),
            if (canAdmin)
              SwitchListTile(
                dense: true,
                title: const Text('Active'),
                subtitle: const Text('Inactive users cannot sign in to any data, whatever their roles.'),
                value: u.isActive,
                onChanged: u.id == profile?.userId
                    ? null
                    : (v) async {
                        final ok = await runWithFeedback(context, () => ref.read(iamRepositoryProvider).updateUser(u.id, isActive: v));
                        if (ok) {
                          ref.invalidate(userProvider(userId));
                          ref.invalidate(usersProvider);
                        }
                      },
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Roles and scope', style: Theme.of(context).textTheme.titleSmall)),
                  if (canAdmin)
                    TextButton(onPressed: () => showSheet(context, _AssignRoleForm(userId: userId)), child: const Text('Assign role')),
                ],
              ),
            ),
            AsyncValueView(
              value: assignments,
              onRetry: () => ref.invalidate(userAssignmentsProvider(userId)),
              data: (list) => Column(
                children: [
                  if (list.isEmpty) const EmptyState('No roles. This user can sign in but sees nothing.'),
                  for (final a in list) ...[
                    ListTile(
                      dense: true,
                      title: Text(a.roleName),
                      subtitle: Text([
                        'at ${ref.watch(orgUnitByIdProvider(a.orgUnitId))?.name ?? '…'}',
                        a.includeDescendants ? 'and everything below' : 'this unit only',
                        'from ${dates.formatMediumDate(a.validFrom)}',
                        if (a.validTo != null) 'until ${dates.formatMediumDate(a.validTo!)}',
                        if (a.isExpired) 'expired',
                      ].join(' · ')),
                      trailing: canAdmin
                          ? IconButton(
                              tooltip: 'Revoke',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () async {
                                final yes = await confirm(context,
                                    title: 'Revoke ${a.roleName}?', message: 'The user loses these permissions immediately.', action: 'Revoke');
                                if (!yes || !context.mounted) return;
                                final ok = await runWithFeedback(context, () => ref.read(iamRepositoryProvider).revokeAssignment(a.id));
                                if (ok) ref.invalidate(userAssignmentsProvider(userId));
                              },
                            )
                          : null,
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, String label, String? value) => ListTile(
        dense: true,
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value ?? '—', style: Theme.of(context).textTheme.bodyMedium),
      );
}

class _AssignRoleForm extends ConsumerStatefulWidget {
  const _AssignRoleForm({required this.userId});
  final String userId;

  @override
  ConsumerState<_AssignRoleForm> createState() => _AssignRoleFormState();
}

class _AssignRoleFormState extends ConsumerState<_AssignRoleForm> {
  String? _roleId;
  String? _scopeId;
  bool _descendants = true;
  DateTime _from = DateTime.now();
  DateTime? _to;

  Future<void> _save() async {
    if (_roleId == null || _scopeId == null) {
      showMessage(context, 'Choose a role and a scope.');
      return;
    }
    final ok = await runWithFeedback(
      context,
      () => ref.read(iamRepositoryProvider).assignRole(
            tenantId: ref.read(accessProfileProvider)!.tenantId,
            userId: widget.userId,
            roleId: _roleId!,
            orgUnitId: _scopeId!,
            includeDescendants: _descendants,
            validFrom: _from,
            validTo: _to,
          ),
    );
    if (ok && mounted) {
      ref.invalidate(userAssignmentsProvider(widget.userId));
      Navigator.pop(context);
    }
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).value ?? const <Role>[];
    final dates = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Assign role', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('You can only grant permissions you hold yourself at that scope.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _roleId,
          decoration: const InputDecoration(labelText: 'Role (what)', isDense: true),
          items: [for (final r in roles) DropdownMenuItem(value: r.id, child: Text(r.isTemplate ? r.name : '${r.name} (custom)'))],
          onChanged: (v) => setState(() => _roleId = v),
        ),
        const SizedBox(height: 8),
        OrgUnitSelector(label: 'Scope (where)', value: _scopeId, onChanged: (u) => setState(() => _scopeId = u.id)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include all units below'),
          value: _descendants,
          onChanged: (v) => setState(() => _descendants = v),
        ),
        Row(
          children: [
            Expanded(child: Text('From ${dates.formatMediumDate(_from)}')),
            TextButton(
              onPressed: () async {
                final d = await _pickDate(_from);
                if (d != null) setState(() => _from = d);
              },
              child: const Text('Change'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text(_to == null ? 'No end date' : 'Until ${dates.formatMediumDate(_to!)}')),
            TextButton(
              onPressed: () async {
                final d = await _pickDate(_to);
                if (d != null) setState(() => _to = d);
              },
              child: const Text('Set end'),
            ),
            if (_to != null) TextButton(onPressed: () => setState(() => _to = null), child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: _save, child: const Text('Assign')),
          ],
        ),
      ],
    );
  }
}
