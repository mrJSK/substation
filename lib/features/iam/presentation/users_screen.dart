import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../../org/application/org_providers.dart';
import '../../org/presentation/org_unit_picker.dart';
import '../application/iam_providers.dart';
import '../data/iam_repository.dart';
import 'user_detail_screen.dart';

/// SU01 — User Maintenance.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _query = '';
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);
    final canCreate = ref.watch(accessProfileProvider)?.canAnywhere('USER_ADMIN') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          if (canCreate) TextButton(onPressed: () => showSheet(context, const _CreateUserForm()), child: const Text('New user')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(isDense: true, hintText: 'Search name, ID, email', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showInactive = !_showInactive),
                  child: Text(_showInactive ? 'Hide inactive' : 'Show inactive'),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: users,
              onRetry: () => ref.invalidate(usersProvider),
              data: (list) {
                final visible = list.where((u) {
                  if (!_showInactive && !u.isActive) return false;
                  if (_query.isEmpty) return true;
                  return [u.fullName, u.employeeId, u.email, u.designation]
                      .any((f) => f?.toLowerCase().contains(_query) ?? false);
                }).toList();
                if (visible.isEmpty) return const EmptyState('No users found.');
                return ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = visible[i];
                    final home = u.homeOrgUnitId == null ? null : ref.watch(orgUnitByIdProvider(u.homeOrgUnitId!));
                    return ListTile(
                      dense: true,
                      title: Text(u.fullName),
                      subtitle: Text([u.designation, home?.name, if (!u.isActive) 'Inactive'].whereType<String>().join(' · ')),
                      trailing: Text(u.employeeId ?? '', style: Theme.of(context).textTheme.bodySmall),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(userId: u.id))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateUserForm extends ConsumerStatefulWidget {
  const _CreateUserForm();

  @override
  ConsumerState<_CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends ConsumerState<_CreateUserForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _employeeId = TextEditingController();
  final _designation = TextEditingController();
  final _phone = TextEditingController();
  String? _homeUnitId;
  String? _roleId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _employeeId, _designation, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_homeUnitId == null) {
      showMessage(context, 'Choose the home unit.');
      return;
    }
    setState(() => _saving = true);
    final ok = await runWithFeedback(
      context,
      () => ref.read(iamRepositoryProvider).createUser(
            email: _email.text.trim(),
            temporaryPassword: _password.text,
            fullName: _name.text.trim(),
            homeOrgUnitId: _homeUnitId!,
            employeeId: _opt(_employeeId),
            designation: _opt(_designation),
            phone: _opt(_phone),
            roleId: _roleId,
          ),
      success: 'User created. Share the temporary password securely.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.invalidate(usersProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).value ?? const [];
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New user', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name', isDense: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (sign-in ID)', isDense: true),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Temporary password', isDense: true),
            validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _employeeId, decoration: const InputDecoration(labelText: 'Employee ID', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone', isDense: true))),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(controller: _designation, decoration: const InputDecoration(labelText: 'Designation', isDense: true)),
          const SizedBox(height: 8),
          OrgUnitSelector(label: 'Home unit (posting)', value: _homeUnitId, onChanged: (u) => setState(() => _homeUnitId = u.id)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _roleId,
            decoration: const InputDecoration(labelText: 'First role at home unit (optional)', isDense: true),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              for (final r in roles) DropdownMenuItem<String?>(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setState(() => _roleId = v),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Creating…' : 'Create')),
            ],
          ),
        ],
      ),
    );
  }
}
