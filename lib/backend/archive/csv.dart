/// Minimal RFC 4180 CSV with a configurable delimiter: quoted fields may
/// hold delimiters, doubled quotes and line breaks.
library;

/// Parses [text] into rows of fields. A leading byte-order mark is dropped
/// and a trailing empty line is not a row.
List<List<String>> parseCsv(String text, {String delimiter = ','}) {
  assert(delimiter.length == 1, 'delimiter must be one character');
  final source = text.startsWith('﻿') ? text.substring(1) : text;
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var fieldStarted = false;

  void endField() {
    row.add(field.toString());
    field.clear();
    fieldStarted = false;
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (inQuotes) {
      if (char != '"') {
        field.write(char);
      } else if (i + 1 < source.length && source[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        inQuotes = false;
      }
    } else if (char == '"' && !fieldStarted) {
      inQuotes = true;
      fieldStarted = true;
    } else if (char == delimiter) {
      endField();
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      endRow();
    } else {
      field.write(char);
      fieldStarted = true;
    }
  }
  if (inQuotes) throw const FormatException('Unterminated quoted field');
  if (fieldStarted || row.isNotEmpty) endRow();
  return rows;
}

/// Writes [rows] as CSV, quoting only fields that need it, with CRLF line
/// ends as RFC 4180 specifies.
String encodeCsv(List<List<Object?>> rows, {String delimiter = ','}) {
  String encodeField(Object? value) {
    final text = value?.toString() ?? '';
    final needsQuotes =
        text.contains(delimiter) ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
  }

  return rows.map((row) => row.map(encodeField).join(delimiter)).join('\r\n');
}
