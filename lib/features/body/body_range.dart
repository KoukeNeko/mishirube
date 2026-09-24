/// How far back a body chart reaches.
enum BodyRange {
  month('30 天', Duration(days: 30)),
  quarter('90 天', Duration(days: 90)),
  year('1 年', Duration(days: 365));

  const BodyRange(this.label, this.window);

  final String label;
  final Duration window;
}

/// `9 月 22 日`.
String bodyDate(DateTime time) => '${time.month} 月 ${time.day} 日';
