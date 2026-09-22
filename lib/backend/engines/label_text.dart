import '../../domain/domain.dart';

/// Puts lines read off a label back into rows.
///
/// Text recognition returns 「熱量」, 「120 大卡」 and 「400 大卡」 as three
/// pieces with positions. A model given them in any other order can pair
/// the wrong number with the wrong nutrient — the failure the research
/// warns about more than misread digits — so pieces whose middles sit
/// within half a line of each other become one row, left to right, and
/// rows go top to bottom.
String labelTextFrom(Iterable<TextLine> lines) {
  final pieces = [
    for (final line in lines)
      if (line.text.trim().isNotEmpty) line,
  ]..sort((a, b) => a.centreY.compareTo(b.centreY));
  if (pieces.isEmpty) return '';

  final rows = <List<TextLine>>[];
  for (final piece in pieces) {
    final row = rows.isEmpty ? null : rows.last;
    final first = row?.first;
    if (row != null &&
        first != null &&
        (piece.centreY - first.centreY).abs() <
            (first.height < piece.height ? first.height : piece.height) / 2) {
      row.add(piece);
    } else {
      rows.add([piece]);
    }
  }
  return [
    for (final row in rows)
      ([...row]..sort((a, b) => a.left.compareTo(b.left)))
          .map((piece) => piece.text.trim())
          .join('  '),
  ].join('\n');
}
