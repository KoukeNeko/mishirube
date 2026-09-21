/// Something the user wanted to write down about a day, in their words.
///
/// Not a measurement and not graded: the log shows it, and nothing adds
/// it up.
class Note {
  const Note({required this.id, required this.notedAt, required this.text});

  final String id;
  final DateTime notedAt;
  final String text;
}
