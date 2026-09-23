import '../backend/storage/database.dart';

/// Where a record came from, in the words the screens show.
String changeSourceLabel(ChangeSource? source) => switch (source) {
  ChangeSource.local => '手動輸入',
  ChangeSource.seed => '示範資料',
  ChangeSource.strongImport || ChangeSource.archiveImport => '匯入',
  ChangeSource.aiDraft => 'AI 草稿（已確認）',
  ChangeSource.catalogue => '內建目錄',
  ChangeSource.healthKit => 'Apple 健康',
  ChangeSource.healthConnect => 'Health Connect',
  null => '不明',
};
