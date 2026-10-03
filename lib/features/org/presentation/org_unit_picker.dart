import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../application/org_providers.dart';
import '../domain/org_models.dart';

/// Public widget of the Org module: pick any unit at any level.
Future<OrgUnit?> pickOrgUnit(BuildContext context, {String title = 'Choose org unit', bool Function(OrgUnit)? where}) {
  return showDialog<OrgUnit>(
    context: context,
    builder: (_) => _OrgUnitPickerDialog(title: title, where: where),
  );
}

class _OrgUnitPickerDialog extends ConsumerStatefulWidget {
  const _OrgUnitPickerDialog({required this.title, this.where});
  final String title;
  final bool Function(OrgUnit)? where;

  @override
  ConsumerState<_OrgUnitPickerDialog> createState() => _OrgUnitPickerDialogState();
}

class _OrgUnitPickerDialogState extends ConsumerState<_OrgUnitPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(orgTreeProvider);
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(isDense: true, hintText: 'Search name or code', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncValueView(
                value: tree,
                onRetry: () => ref.invalidate(orgTreeProvider),
                data: (units) {
                  final visible = units.where((u) {
                    if (widget.where != null && !widget.where!(u)) return false;
                    if (_query.isEmpty) return true;
                    return u.name.toLowerCase().contains(_query) || u.code.toLowerCase().contains(_query);
                  }).toList();
                  if (visible.isEmpty) return const EmptyState('No matching units.');
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final u = visible[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.only(left: _query.isEmpty ? 8.0 + (u.depth - 1) * 16 : 8, right: 8),
                        title: Text(u.name),
                        subtitle: Text('${u.levelName} · ${u.code}'),
                        enabled: u.isActive,
                        onTap: () => Navigator.pop(context, u),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}

/// Form row showing a chosen unit with a "Choose" action.
class OrgUnitSelector extends ConsumerWidget {
  const OrgUnitSelector({super.key, required this.label, required this.value, required this.onChanged, this.where});

  final String label;
  final String? value;
  final ValueChanged<OrgUnit> onChanged;
  final bool Function(OrgUnit)? where;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = value == null ? null : ref.watch(orgUnitByIdProvider(value!));
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: Row(
        children: [
          Expanded(child: Text(unit == null ? 'Not selected' : '${unit.name} (${unit.levelName})')),
          TextButton(
            onPressed: () async {
              final picked = await pickOrgUnit(context, title: label, where: where);
              if (picked != null) onChanged(picked);
            },
            child: const Text('Choose'),
          ),
        ],
      ),
    );
  }
}
