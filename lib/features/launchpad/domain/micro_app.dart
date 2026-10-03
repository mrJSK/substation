import '../../../core/json.dart';

/// A launchable micro-app (T-code) the signed-in user is allowed to open.
class MicroApp {
  const MicroApp({
    required this.code,
    required this.name,
    required this.module,
    required this.icon,
    this.description,
    this.requiredPermission,
  });

  final String code;
  final String name;
  final String module;
  final String icon;
  final String? description;
  final String? requiredPermission;

  factory MicroApp.fromJson(Map<String, dynamic> json) => MicroApp(
        code: json.str('code'),
        name: json.str('name'),
        module: json.str('module'),
        icon: json.strOrNull('icon') ?? 'apps',
        description: json.strOrNull('description'),
        requiredPermission: json.strOrNull('required_permission'),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'module': module,
        'icon': icon,
        'description': description,
        'required_permission': requiredPermission,
      };
}
