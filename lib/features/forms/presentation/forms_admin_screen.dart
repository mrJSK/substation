import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../../launchpad/application/launchpad_providers.dart';
import '../data/forms_repository.dart';
import '../domain/form_schema.dart';
import 'dynamic_form.dart';

final _allFormsProvider = FutureProvider.autoDispose<List<FormDefinition>>((ref) => ref.watch(formsRepositoryProvider).allForms());
final _catalogProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.watch(formsRepositoryProvider).appCatalog());
final _appSettingsProvider = FutureProvider.autoDispose<Map<String, bool>>((ref) => ref.watch(formsRepositoryProvider).appSettings());

/// UI01 — Forms and Apps: preview/customise dynamic forms, switch micro-apps on or off.
class FormsAdminScreen extends StatelessWidget {
  const FormsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Forms and Apps'),
          bottom: const TabBar(tabs: [Tab(text: 'Forms'), Tab(text: 'Micro-apps')]),
        ),
        body: const TabBarView(children: [_FormsTab(), _AppsTab()]),
      ),
    );
  }
}

class _FormsTab extends ConsumerWidget {
  const _FormsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forms = ref.watch(_allFormsProvider);
    return AsyncValueView(
      value: forms,
      onRetry: () => ref.invalidate(_allFormsProvider),
      data: (list) {
        // Effective version per code: the tenant's own newest version, else the standard one.
        final byCode = <String, FormDefinition>{};
        for (final f in list) {
          final current = byCode[f.code];
          final better = current == null ||
              (f.isTenantOverride && !current.isTenantOverride) ||
              (f.isTenantOverride == current.isTenantOverride && f.version > current.version);
          if (better) byCode[f.code] = f;
        }
        final effective = byCode.values.toList()..sort((a, b) => a.code.compareTo(b.code));
        if (effective.isEmpty) return const EmptyState('No forms defined.');
        return ListView.separated(
          itemCount: effective.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final f = effective[i];
            return ListTile(
              dense: true,
              title: Text(f.title),
              subtitle: Text('${f.code} · v${f.version} · ${f.isTenantOverride ? 'customised' : 'standard'}'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FormPreviewScreen(definition: f))),
            );
          },
        );
      },
    );
  }
}

class FormPreviewScreen extends ConsumerStatefulWidget {
  const FormPreviewScreen({super.key, required this.definition});
  final FormDefinition definition;

  @override
  ConsumerState<FormPreviewScreen> createState() => _FormPreviewScreenState();
}

class _FormPreviewScreenState extends ConsumerState<FormPreviewScreen> {
  final _formKey = GlobalKey<DynamicFormState>();

  void _check() {
    final state = _formKey.currentState!;
    final valid = state.validate();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(valid ? 'Valid' : 'Has errors'),
        content: SingleChildScrollView(child: Text(const JsonEncoder.withIndent('  ').convert(state.values))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCustomise = ref.watch(accessProfileProvider)?.canTenantWide('UI_ADMIN') ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.definition.title),
        actions: [
          TextButton(onPressed: _check, child: const Text('Check')),
          if (canCustomise)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => _FormJsonEditor(definition: widget.definition)),
              ),
              child: const Text('Customise'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: DynamicForm(key: _formKey, schema: widget.definition.schema),
        ),
      ),
    );
  }
}

class _FormJsonEditor extends ConsumerStatefulWidget {
  const _FormJsonEditor({required this.definition});
  final FormDefinition definition;

  @override
  ConsumerState<_FormJsonEditor> createState() => _FormJsonEditorState();
}

class _FormJsonEditorState extends ConsumerState<_FormJsonEditor> {
  late final _text = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(widget.definition.rawSchema));
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final Map<String, dynamic> schema;
    try {
      schema = (jsonDecode(_text.text) as Map).cast<String, dynamic>();
      FormSchema.fromJson(schema);
    } catch (e) {
      setState(() => _error = 'Invalid form JSON: $e');
      return;
    }
    final ok = await runWithFeedback(
      context,
      () => ref.read(formsRepositoryProvider).saveOverride(
            tenantId: ref.read(accessProfileProvider)!.tenantId,
            base: widget.definition,
            schema: schema,
          ),
      success: 'Saved as version ${widget.definition.version + 1} for your organisation.',
    );
    if (ok && mounted) {
      ref.invalidate(_allFormsProvider);
      ref.invalidate(formDefinitionProvider(widget.definition.code));
      Navigator.of(context)
        ..pop()
        ..pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Customise ${widget.definition.code}'),
        actions: [TextButton(onPressed: _save, child: const Text('Save version'))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Expanded(
              child: TextField(
                controller: _text,
                expands: true,
                maxLines: null,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppsTab extends ConsumerWidget {
  const _AppsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(_catalogProvider);
    final settings = ref.watch(_appSettingsProvider);
    final canEdit = ref.watch(accessProfileProvider)?.canTenantWide('UI_ADMIN') ?? false;

    return AsyncValueView(
      value: catalog,
      onRetry: () => ref.invalidate(_catalogProvider),
      data: (apps) => ListView.separated(
        itemCount: apps.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final app = apps[i];
          final code = app['code'] as String;
          final enabled = settings.value?[code] ?? true;
          return SwitchListTile(
            dense: true,
            title: Text('${app['name']}'),
            subtitle: Text('$code · ${app['module']} · needs ${app['required_permission'] ?? 'any role'}'),
            value: enabled,
            onChanged: !canEdit || code == 'UI01'
                ? null
                : (v) async {
                    final ok = await runWithFeedback(
                      context,
                      () => ref.read(formsRepositoryProvider).setAppEnabled(
                            tenantId: ref.read(accessProfileProvider)!.tenantId, appCode: code, enabled: v),
                    );
                    if (ok) {
                      ref.invalidate(_appSettingsProvider);
                      ref.invalidate(myAppsProvider);
                    }
                  },
          );
        },
      ),
    );
  }
}
