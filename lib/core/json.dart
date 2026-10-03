/// Tolerant readers for Supabase JSON (numbers may arrive as int or double,
/// dates as ISO strings).
extension JsonRead on Map<String, dynamic> {
  String str(String key) => this[key] as String;
  String? strOrNull(String key) => this[key] as String?;
  bool boolOr(String key, bool fallback) => (this[key] as bool?) ?? fallback;
  int? intOrNull(String key) => (this[key] as num?)?.toInt();
  double? doubleOrNull(String key) => (this[key] as num?)?.toDouble();
  DateTime? dateOrNull(String key) {
    final v = this[key] as String?;
    return v == null ? null : DateTime.parse(v);
  }

  Map<String, dynamic>? mapOrNull(String key) => (this[key] as Map?)?.cast<String, dynamic>();
  List<Map<String, dynamic>> mapList(String key) =>
      ((this[key] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
