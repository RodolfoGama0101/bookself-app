import 'dart:convert';
import '../data/models/couple_record.dart';

/// Compara apenas seleções deliberadamente compartilhadas na lista atual.
/// Texto semelhante não comprova a identidade de uma obra/edição.
List<CoupleSelection> commonCoupleSelections(
  Iterable<CoupleRecord> rows,
  String uid,
  String partnerUid,
) {
  if (uid == partnerUid) return [];
  String normalize(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  final groups = <String, (CoupleSelection, Set<String>)>{};
  for (final row in rows) {
    if (row.data['removed'] == true ||
        (row.author != uid && row.author != partnerUid)) {
      continue;
    }
    final selection = row.selection;
    final key = jsonEncode([
      selection.type.name,
      selection.source,
      selection.reference,
      normalize(selection.title),
      normalize(selection.subtitle),
      selection.episode?['season'],
      selection.episode?['number'],
    ]);
    final group = groups.putIfAbsent(key, () => (selection, <String>{}));
    group.$2.add(row.author);
  }
  final matches = groups.values
      .where((group) => group.$2.contains(uid) && group.$2.contains(partnerUid))
      .map((group) => group.$1)
      .toList();
  matches.sort((a, b) {
    final type = a.type.index.compareTo(b.type.index);
    if (type != 0) return type;
    final title = normalize(a.title).compareTo(normalize(b.title));
    if (title != 0) return title;
    return jsonEncode(a.toMap()).compareTo(jsonEncode(b.toMap()));
  });
  return matches;
}
