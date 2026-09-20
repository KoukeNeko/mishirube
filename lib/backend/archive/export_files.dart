import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../backend.dart';
import 'canonical_archive.dart';
import 'csv_view.dart';

/// Writing exports to files the user can reach.
extension BackendExports on Backend {
  /// Writes the full JSON archive to the exports folder.
  Future<File> writeArchive() async {
    final file = File(
      p.join((await _exportDirectory()).path, 'mishirube-${_stamp()}.json'),
    );
    return file.writeAsString(encodeArchive(exportArchive(db)));
  }

  /// Writes the CSV views into their own folder under exports.
  Future<Directory> writeCsvViews() async {
    final directory = await Directory(
      p.join((await _exportDirectory()).path, 'mishirube-csv-${_stamp()}'),
    ).create();
    for (final MapEntry(key: name, value: csv) in exportCsvViews(db).entries) {
      await File(p.join(directory.path, name)).writeAsString(csv);
    }
    return directory;
  }

  /// Exports go to Documents, which the Files app and file sharing expose.
  Future<Directory> _exportDirectory() async => Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'exports'),
  ).create(recursive: true);

  String _stamp() {
    final now = db.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
