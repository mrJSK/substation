import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/routes.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../application/launchpad_providers.dart';
import '../domain/micro_app.dart';

/// Home: the user's micro-apps grouped by module, plus a T-code command box.
class LaunchpadScreen extends ConsumerWidget {
  const LaunchpadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accessProfileProvider);
    final apps = ref.watch(myAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.tenantName ?? 'GridERP'),
        actions: [
          const SizedBox(width: 140, child: TCodeField()),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) async {
              if (value == 'reload') await ref.read(sessionProvider.notifier).reload();
              if (value == 'signout') await ref.read(sessionProvider.notifier).signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(profile?.fullName ?? '')),
              const PopupMenuItem(value: 'reload', child: Text('Refresh my access')),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profile?.fromCache ?? false)
            Container(
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Text('Offline: showing your saved access.', style: TextStyle(fontSize: 12)),
            ),
          Expanded(
            child: AsyncValueView(
              value: apps,
              onRetry: () => ref.invalidate(myAppsProvider),
              data: (list) => list.isEmpty
                  ? const EmptyState('No apps are assigned to you yet. Ask your administrator for a role.')
                  : _AppGroups(apps: list),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppGroups extends StatelessWidget {
  const _AppGroups({required this.apps});
  final List<MicroApp> apps;

  @override
  Widget build(BuildContext context) {
    final byModule = <String, List<MicroApp>>{};
    for (final app in apps) {
      byModule.putIfAbsent(app.module, () => []).add(app);
    }
    final columns = MediaQuery.sizeOf(context).width >= 900 ? 6 : (MediaQuery.sizeOf(context).width >= 600 ? 4 : 3);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in byModule.entries) ...[
          SectionLabel(entry.key),
          GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [for (final app in entry.value) _AppTile(app: app)],
          ),
        ],
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app});
  final MicroApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: app.description ?? app.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openMicroApp(context, app.code),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(appIcon(app.icon), color: theme.colorScheme.primary),
                const SizedBox(height: 6),
                Text(app.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                Text(app.code, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SAP-style command field: type a T-code and press Enter.
class TCodeField extends ConsumerStatefulWidget {
  const TCodeField({super.key});

  @override
  ConsumerState<TCodeField> createState() => _TCodeFieldState();
}

class _TCodeFieldState extends ConsumerState<TCodeField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(String value) {
    final code = value.trim().toUpperCase();
    if (code.isEmpty) return;
    if (ref.read(myAppByCodeProvider(code)) == null) {
      showMessage(context, 'No app $code, or you do not have access to it.');
      return;
    }
    _controller.clear();
    openMicroApp(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: _controller,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.go,
        onSubmitted: _open,
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'T-code',
          prefixIcon: Icon(Icons.keyboard_command_key, size: 16),
          prefixIconConstraints: BoxConstraints(minWidth: 32),
        ),
      ),
    );
  }
}
