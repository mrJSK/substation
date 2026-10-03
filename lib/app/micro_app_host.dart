import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/launchpad/application/launchpad_providers.dart';
import '../shared/widgets/app_icons.dart';
import '../shared/widgets/async_value_view.dart';
import 'micro_app_registry.dart';

/// Opens a micro-app by T-code after checking the user may launch it.
class MicroAppHost extends ConsumerWidget {
  const MicroAppHost({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(myAppsProvider);
    return AsyncValueView(
      value: apps,
      onRetry: () => ref.invalidate(myAppsProvider),
      data: (_) {
        final app = ref.watch(myAppByCodeProvider(code));
        if (app == null) {
          return Scaffold(
            appBar: AppBar(title: Text(code)),
            body: EmptyState('$code does not exist or is not assigned to you.'),
          );
        }
        final builder = microAppScreens[code];
        if (builder != null) return builder(context);
        return Scaffold(
          appBar: AppBar(title: Text(app.name)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(appIcon(app.icon), size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text('${app.code} · ${app.name}', style: Theme.of(context).textTheme.titleMedium),
                if (app.description != null) Text(app.description!, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('This app is not released yet.'),
              ],
            ),
          ),
        );
      },
    );
  }
}
