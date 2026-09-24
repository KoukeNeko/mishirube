import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// What happens to the user's data, in plain statements that match what
/// the app does. Health Connect opens this page from its permission
/// screens; it is also under 我的.
///
/// Every line here is a promise the code keeps. Change the behaviour and
/// this page changes with it, or it becomes the thing it warns against.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final platform = store.healthSourceName;
    final kinds = [
      for (final kind in HealthDataKind.values)
        if (store.healthKinds.contains(kind)) kind.label,
    ];
    return DetailPage(
      appBar: const PageAppBar(title: '隱私說明'),
      children: [
        const _Facts(
          title: '儲存',
          facts: [
            ('紀錄', '只在這台裝置'),
            ('帳號', '無'),
            ('伺服器', '無'),
            ('刪除的紀錄', '可復原'),
            ('解除安裝 App', '清除所有紀錄'),
          ],
        ),
        const _Facts(
          title: '相機與相簿',
          facts: [
            ('相機', '只在掃描時開啟'),
            ('相簿', '讀取最新一張做為選取按鈕的縮圖'),
            ('體脂計與圍度照片', '在裝置上讀取數字，不送出'),
          ],
        ),
        _Facts(
          title: '健康資料（$platform）',
          facts: [
            ('權限', '只讀，不寫入'),
            ('讀取', '第一次讀取最近 6 個月，之後開啟 App 時讀取最近 30 天'),
            ('送出裝置', '否'),
            ('提供給 AI', '否'),
            ('用於廣告', '否'),
            ('中斷連接後', '已讀入的紀錄保留'),
            if (kinds.isNotEmpty) ('讀取類別', kinds.join('、')),
          ],
        ),
        const _Facts(
          title: 'AI',
          facts: [
            ('預設', '不使用'),
            ('Apple Intelligence', '在裝置上執行'),
            ('雲端 AI 收到', '輸入的文字、照片辨識出的文字、估算用的食物照片'),
            ('食物照片', '先移除位置與拍攝資訊，不保存'),
            ('其他照片、其他紀錄、健康資料', '不送出'),
            ('第一次送出文字或照片前', '分別詢問同意，可在「我的 > AI」撤回'),
            ('AI 的結果', '草稿，確認後才記錄'),
            ('Google AI Studio 免費額度', '內容可能用於改進產品並經人工審閱'),
          ],
        ),
        const _Facts(
          title: '金鑰與匯出',
          facts: [
            ('API 金鑰', '系統安全儲存區，不進資料庫'),
            ('匯出檔案', '只在「我的 > 匯出」手動建立'),
            ('匯出內容', '不含 API 金鑰'),
            ('上傳', '無'),
          ],
        ),
      ],
    );
  }
}

/// One area's promises, each a label and what the app does about it.
class _Facts extends StatelessWidget {
  const _Facts({required this.title, required this.facts});

  final String title;
  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    return PageSection(
      label: title,
      children: [
        Gutter(
          child: GroupedCard(
            children: [
              for (final (label, value) in facts)
                KeyValueRow(label: label, value: value),
            ],
          ),
        ),
      ],
    );
  }
}
