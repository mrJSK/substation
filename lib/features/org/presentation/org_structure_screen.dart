import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../application/org_providers.dart';
import '../data/org_repository.dart';
import '../domain/org_models.dart';
import 'org_editors.dart';

/// OR01 — Org Structure: levels, units (any depth), cross-level sharing.
class OrgStructureScreen extends StatelessWidget {
  const OrgStructureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Org Structure'),
          bottom: const TabBar(tabs: [Tab(text: 'Units'), Tab(text: 'Levels'), Tab(text: 'Sharing')]),
        ),
        body: const TabBarView(children: [_UnitsTab(), _LevelsTab(), _SharingTab()]),
      ),
    );
  }
}

// ── Units ─────────────────────────────────────────────────────────────────
class _UnitsTab extends ConsumerStatefulWidget {
  const _UnitsTab();

  @override
  ConsumerState<_UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends ConsumerState<_UnitsTab> {
  final _collapsed = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(orgTreeProvider);
    final profile = ref.watch(accessProfileProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(isDense: true, hintText: 'Search', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              if (profile?.canTenantWide('ORG_ADMIN') ?? false)
                TextButton(
                  onPressed: () => showSheet(context, const UnitEditor()),
                  child: const Text('Add top unit'),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: tree,
            onRetry: () => ref.invalidate(orgTreeProvider),
            data: (units) {
              if (units.isEmpty) return const EmptyState('No units yet.');
              final rows = _visibleRows(units);
              return RefreshIndicator(
                onRefresh: () => ref.refresh(orgTreeProvider.future),
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _unitRow(rows[i], units, profile?.can('ORG_ADMIN', unitPath: rows[i].path) ?? false),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<OrgUnit> _visibleRows(List<OrgUnit> units) {
    if (_query.isNotEmpty) {
      return units.where((u) => u.name.toLowerCase().contains(_query) || u.code.toLowerCase().contains(_query)).toList();
    }
    return units.where((u) => !_collapsed.any((c) => u.path.startsWith('${units.firstWhere((x) => x.id == c).path}.'))).toList();
  }

  Widget _unitRow(OrgUnit u, List<OrgUnit> all, bool canEdit) {
    final hasChildren = all.any((x) => x.parentId == u.id);
    final collapsed = _collapsed.contains(u.id);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: _query.isEmpty ? 4.0 + (u.depth - 1) * 20 : 4, right: 4),
      leading: hasChildren && _query.isEmpty
          ? IconButton(
              tooltip: collapsed ? 'Expand' : 'Collapse',
              icon: Icon(collapsed ? Icons.chevron_right : Icons.expand_more),
              onPressed: () => setState(() => collapsed ? _collapsed.remove(u.id) : _collapsed.add(u.id)),
            )
          : const SizedBox(width: 48),
      title: Text(u.name, style: TextStyle(color: u.isActive ? null : Theme.of(context).disabledColor)),
      subtitle: Text([
        u.levelName,
        u.code,
        if (u.voltageKv != null) '${u.voltageKv!.toStringAsFixed(0)} kV',
        if (!u.isActive) 'Inactive',
      ].join(' · ')),
      trailing: canEdit
          ? PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (action) async {
                if (action == 'child') return showSheet(context, UnitEditor(parent: u));
                if (action == 'edit') return showSheet(context, UnitEditor(unit: u));
                if (action == 'delete') {
                  final yes = await confirm(context,
                      title: 'Delete ${u.name}?',
                      message: 'Only possible when it has no child units, equipment or records. Prefer marking it inactive.',
                      action: 'Delete');
                  if (yes && mounted) {
                    final ok = await runWithFeedback(context, () => ref.read(orgRepositoryProvider).deleteUnit(u.id));
                    if (ok) ref.invalidate(orgTreeProvider);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'child', child: Text('Add unit below')),
                PopupMenuItem(value: 'edit', child: Text('Edit or move')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          : null,
    );
  }
}

// ── Levels ────────────────────────────────────────────────────────────────
class _LevelsTab extends ConsumerWidget {
  const _LevelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(orgLevelsProvider);
    final canEdit = ref.watch(accessProfileProvider)?.canTenantWide('ORG_ADMIN') ?? false;

    return AsyncValueView(
      value: levels,
      onRetry: () => ref.invalidate(orgLevelsProvider),
      data: (list) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Your organisation defines its own levels. A unit must sit at a lower level than its parent; levels may be skipped.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                if (canEdit)
                  TextButton(
                    onPressed: () => showSheet(context, LevelEditor(nextRank: list.isEmpty ? 1 : list.last.rank + 1)),
                    child: const Text('Add level'),
                  ),
              ],
            ),
          ),
          for (final l in list) ...[
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 14, child: Text('${l.rank}', style: const TextStyle(fontSize: 12))),
              title: Text(l.name),
              subtitle: Text(l.isOperational ? '${l.code} · operational level' : l.code),
              onTap: canEdit ? () => showSheet(context, LevelEditor(level: l, nextRank: l.rank)) : null,
              trailing: canEdit
                  ? IconButton(
                      tooltip: 'Delete level',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final yes = await confirm(context,
                            title: 'Delete level ${l.name}?', message: 'Only possible when no unit uses it.', action: 'Delete');
                        if (yes && context.mounted) {
                          final ok = await runWithFeedback(context, () => ref.read(orgRepositoryProvider).deleteLevel(l.id));
                          if (ok) ref.invalidate(orgLevelsProvider);
                        }
                      },
                    )
                  : null,
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

// ── Sharing ───────────────────────────────────────────────────────────────
class _SharingTab extends ConsumerWidget {
  const _SharingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = ref.watch(orgSharesProvider);
    final canShare = ref.watch(accessProfileProvider)?.canAnywhere('ORG_ADMIN') ?? false;
    final dates = MaterialLocalizations.of(context);

    return AsyncValueView(
      value: shares,
      onRetry: () => ref.invalidate(orgSharesProvider),
      data: (list) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Give people at one unit read access to another unit at any level, e.g. SLDC reading a substation.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                if (canShare) TextButton(onPressed: () => showSheet(context, const ShareEditor()), child: const Text('New share')),
              ],
            ),
          ),
          if (list.isEmpty) const EmptyState('Nothing is shared.'),
          for (final s in list) ...[
            ListTile(
              dense: true,
              title: Text('${ref.watch(orgUnitByIdProvider(s.sourceId))?.name ?? '…'}  →  '
                  '${ref.watch(orgUnitByIdProvider(s.targetId))?.name ?? '…'}'),
              subtitle: Text([
                'From ${dates.formatMediumDate(s.validFrom)}',
                if (s.validTo != null) 'until ${dates.formatMediumDate(s.validTo!)}',
                if (s.reason != null) s.reason!,
              ].join(' · ')),
              trailing: canShare
                  ? IconButton(
                      tooltip: 'Remove share',
                      icon: const Icon(Icons.link_off),
                      onPressed: () async {
                        final ok = await runWithFeedback(context, () => ref.read(orgRepositoryProvider).deleteShare(s.id));
                        if (ok) ref.invalidate(orgSharesProvider);
                      },
                    )
                  : null,
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
