import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../application/org_providers.dart';
import '../data/org_repository.dart';
import '../domain/org_models.dart';
import 'org_unit_picker.dart';

// ── Level editor ──────────────────────────────────────────────────────────
class LevelEditor extends ConsumerStatefulWidget {
  const LevelEditor({super.key, this.level, required this.nextRank});
  final OrgLevel? level;
  final int nextRank;

  @override
  ConsumerState<LevelEditor> createState() => _LevelEditorState();
}

class _LevelEditorState extends ConsumerState<LevelEditor> {
  final _form = GlobalKey<FormState>();
  late final _rank = TextEditingController(text: '${widget.level?.rank ?? widget.nextRank}');
  late final _name = TextEditingController(text: widget.level?.name);
  late final _code = TextEditingController(text: widget.level?.code);
  late bool _operational = widget.level?.isOperational ?? false;

  @override
  void dispose() {
    _rank.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runWithFeedback(context, () => ref.read(orgRepositoryProvider).saveLevel(
          id: widget.level?.id,
          tenantId: ref.read(accessProfileProvider)!.tenantId,
          rank: int.parse(_rank.text),
          name: _name.text.trim(),
          code: _code.text.trim().toUpperCase(),
          isOperational: _operational,
        ));
    if (ok && mounted) {
      ref.invalidate(orgLevelsProvider);
      ref.invalidate(orgTreeProvider);
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
          Text(widget.level == null ? 'New level' : 'Edit level', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rank,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Rank (1 = top)', isDense: true),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return (n == null || n < 1 || n > 20) ? 'Enter 1 to 20' : null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name, e.g. Circle', isDense: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Short code, e.g. CR', isDense: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Operational level'),
            subtitle: const Text('Shifts, logsheets and permits happen at units of this level'),
            value: _operational,
            onChanged: (v) => setState(() => _operational = v),
          ),
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

// ── Unit editor (create child / edit / move) ─────────────────────────────
class UnitEditor extends ConsumerStatefulWidget {
  const UnitEditor({super.key, this.unit, this.parent});
  final OrgUnit? unit;     // null = create
  final OrgUnit? parent;   // default parent when creating

  @override
  ConsumerState<UnitEditor> createState() => _UnitEditorState();
}

class _UnitEditorState extends ConsumerState<UnitEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.unit?.name);
  late final _code = TextEditingController(text: widget.unit?.code);
  late final _voltage = TextEditingController(text: widget.unit?.voltageKv?.toString() ?? '');
  late final _consumers = TextEditingController(text: '${widget.unit?.totalConsumers ?? 0}');
  late String? _parentId = widget.unit?.parentId ?? widget.parent?.id;
  late String? _levelId = widget.unit?.levelId;
  late bool _active = widget.unit?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _voltage.dispose();
    _consumers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(orgRepositoryProvider);
    final voltage = double.tryParse(_voltage.text);
    final consumers = int.tryParse(_consumers.text) ?? 0;
    final ok = await runWithFeedback(context, () async {
      if (widget.unit == null) {
        await repo.createUnit(
          tenantId: ref.read(accessProfileProvider)!.tenantId,
          parentId: _parentId, levelId: _levelId!, name: _name.text.trim(), code: _code.text.trim().toUpperCase(),
          voltageKv: voltage, totalConsumers: consumers,
        );
      } else {
        await repo.updateUnit(widget.unit!.id,
            parentId: _parentId, levelId: _levelId!, name: _name.text.trim(), code: _code.text.trim().toUpperCase(),
            voltageKv: voltage, totalConsumers: consumers, isActive: _active);
      }
    });
    if (ok && mounted) {
      ref.invalidate(orgTreeProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = ref.watch(orgLevelsProvider).value ?? const <OrgLevel>[];
    final parent = _parentId == null ? null : ref.watch(orgUnitByIdProvider(_parentId!));
    final allowedLevels = levels.where((l) => parent == null || l.rank > parent.levelRank).toList();
    final editing = widget.unit;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(editing == null ? 'New unit' : 'Edit ${editing.name}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          OrgUnitSelector(
            label: 'Parent unit',
            value: _parentId,
            where: (u) => editing == null || (u.id != editing.id && !u.isDescendantOf(editing)),
            onChanged: (u) => setState(() {
              _parentId = u.id;
              if (_levelId != null && levels.any((l) => l.id == _levelId && l.rank <= u.levelRank)) _levelId = null;
            }),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: allowedLevels.any((l) => l.id == _levelId) ? _levelId : null,
            decoration: const InputDecoration(labelText: 'Level', isDense: true),
            items: [for (final l in allowedLevels) DropdownMenuItem(value: l.id, child: Text('${l.name} (${l.code})'))],
            onChanged: (v) => setState(() => _levelId = v),
            validator: (v) => v == null ? 'Choose a level below the parent' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name', isDense: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code (unique in your organisation)', isDense: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _voltage,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Voltage (kV)', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _consumers,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Consumers served', isDense: true),
                ),
              ),
            ],
          ),
          if (editing != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          const SizedBox(height: 8),
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

// ── Share editor ──────────────────────────────────────────────────────────
class ShareEditor extends ConsumerStatefulWidget {
  const ShareEditor({super.key});

  @override
  ConsumerState<ShareEditor> createState() => _ShareEditorState();
}

class _ShareEditorState extends ConsumerState<ShareEditor> {
  String? _source;
  String? _target;
  DateTime? _validTo;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_source == null || _target == null || _source == _target) {
      showMessage(context, 'Choose two different units.');
      return;
    }
    final ok = await runWithFeedback(context, () => ref.read(orgRepositoryProvider).createShare(
          tenantId: ref.read(accessProfileProvider)!.tenantId,
          sourceId: _source!, targetId: _target!, validTo: _validTo,
          reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        ));
    if (ok && mounted) {
      ref.invalidate(orgSharesProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Share data across levels', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('People working at the target unit (or above it) can read the source unit and everything under it.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        OrgUnitSelector(label: 'Source: data of', value: _source, onChanged: (u) => setState(() => _source = u.id)),
        const SizedBox(height: 8),
        OrgUnitSelector(label: 'Target: visible to', value: _target, onChanged: (u) => setState(() => _target = u.id)),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Valid until', isDense: true),
          child: Row(
            children: [
              Expanded(child: Text(_validTo == null ? 'No end date' : MaterialLocalizations.of(context).formatMediumDate(_validTo!))),
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (d != null) setState(() => _validTo = d);
                },
                child: const Text('Choose'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason', isDense: true)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: _save, child: const Text('Share')),
          ],
        ),
      ],
    );
  }
}
