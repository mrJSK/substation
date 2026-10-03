import '../../../core/json.dart';

/// A tenant-defined hierarchy level (e.g. Zone, Circle, Substation).
class OrgLevel {
  const OrgLevel({required this.id, required this.rank, required this.name, required this.code, required this.isOperational});

  final String id;
  final int rank;
  final String name;
  final String code;
  final bool isOperational;

  factory OrgLevel.fromJson(Map<String, dynamic> j) => OrgLevel(
        id: j.str('id'),
        rank: j.intOrNull('rank')!,
        name: j.str('name'),
        code: j.str('code'),
        isOperational: j.boolOr('is_operational', false),
      );
}

/// A node of the org tree, as read from the org_tree view.
class OrgUnit {
  const OrgUnit({
    required this.id,
    required this.name,
    required this.code,
    required this.path,
    required this.depth,
    required this.levelId,
    required this.levelName,
    required this.levelRank,
    required this.isOperational,
    required this.isActive,
    required this.totalConsumers,
    this.parentId,
    this.voltageKv,
  });

  final String id;
  final String? parentId;
  final String name;
  final String code;
  final String path;
  final int depth;
  final String levelId;
  final String levelName;
  final int levelRank;
  final bool isOperational;
  final bool isActive;
  final double? voltageKv;
  final int totalConsumers;

  factory OrgUnit.fromJson(Map<String, dynamic> j) => OrgUnit(
        id: j.str('id'),
        parentId: j.strOrNull('parent_id'),
        name: j.str('name'),
        code: j.str('code'),
        path: j.str('path'),
        depth: j.intOrNull('depth')!,
        levelId: j.str('level_id'),
        levelName: j.str('level_name'),
        levelRank: j.intOrNull('level_rank')!,
        isOperational: j.boolOr('is_operational', false),
        isActive: j.boolOr('is_active', true),
        voltageKv: j.doubleOrNull('voltage_kv'),
        totalConsumers: j.intOrNull('total_consumers') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'parent_id': parentId, 'name': name, 'code': code, 'path': path, 'depth': depth,
        'level_id': levelId, 'level_name': levelName, 'level_rank': levelRank, 'is_operational': isOperational,
        'is_active': isActive, 'voltage_kv': voltageKv, 'total_consumers': totalConsumers,
      };

  bool isDescendantOf(OrgUnit other) => path.startsWith('${other.path}.');
}

/// Read access to SOURCE (and below) for users scoped at TARGET.
class OrgShare {
  const OrgShare({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.validFrom,
    this.validTo,
    this.reason,
  });

  final String id;
  final String sourceId;
  final String targetId;
  final DateTime validFrom;
  final DateTime? validTo;
  final String? reason;

  factory OrgShare.fromJson(Map<String, dynamic> j) => OrgShare(
        id: j.str('id'),
        sourceId: j.str('source_org_unit_id'),
        targetId: j.str('target_org_unit_id'),
        validFrom: j.dateOrNull('valid_from')!,
        validTo: j.dateOrNull('valid_to'),
        reason: j.strOrNull('reason'),
      );
}
