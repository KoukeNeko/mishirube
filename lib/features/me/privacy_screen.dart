import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
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
        if (store.healthKinds.contains(kind)) kind,
    ];
    return DetailPage(
      appBar: const PageAppBar(title: '隱私說明', subtitle: '資料去了哪裡'),
      children: [
        Gutter(
          child: const InfoBanner(
            tone: CardTone.training,
            icon: Icons.shield_outlined,
            message: '紀錄存在這台裝置。沒有帳號，也沒有伺服器。',
          ),
        ),
        const _Section(
          title: '資料存在哪裡',
          lines: [
            '紀錄存在 App 自己的資料庫，不離開這台裝置。',
            '刪除的紀錄先標記為已刪除，所以能復原。',
            '解除安裝 App 時，整個資料庫才會清除。',
          ],
        ),
        _Section(
          title: '健康資料（$platform）',
          lines: [
            '按「連接」並允許之後才開始讀取。',
            '每次讀取最近 30 天，打開 App 時重讀一次。',
            '只讀不寫：$platform 裡的資料不會被這個 App 改動。',
            '讀進來的資料成為這裡的紀錄，顯示在紀錄、今天與趨勢。',
            '不送出這台裝置，不給 AI，不用於廣告。',
            '在「我的 > 資料來源」可以隨時中斷連接。',
            '已讀進來的紀錄會保留，要刪就在紀錄裡刪。',
          ],
        ),
        if (kinds.isNotEmpty) ...[
          Gutter(child: const SectionLabel('讀取的類別')),
          Gutter(
            child: GroupedCard(
              children: [
                for (final kind in kinds)
                  KeyValueRow(label: kind.label, value: _useOf(kind)),
              ],
            ),
          ),
        ],
        const _Section(
          title: 'AI',
          lines: [
            '預設不使用 AI。沒選之前什麼都不送出。',
            'Apple Intelligence 在裝置上執行，資料不離開裝置。',
            '雲端 AI 只送出輸入的文字，或從照片辨識出的文字。',
            '其他紀錄與健康資料不送出。',
            '第一次送出前會先詢問，之後可在「我的 > AI」撤回。',
            'Google AI Studio 的免費額度會把送出的內容用於改進 Google 的產品，可能由人工審閱。',
            '掃描營養標示時，照片在裝置上辨識文字，送出的是文字，不是照片。',
            'AI 只產生草稿，確認之後才記錄。',
          ],
        ),
        const _Section(
          title: '金鑰、匯出與備份',
          lines: [
            'API 金鑰存在系統的安全儲存區（iOS 鑰匙圈、Android Keystore），'
                '不進資料庫，也不隨匯出離開。',
            '只有在「我的 > 匯出」手動匯出才會產生檔案，存在 App 自己的資料夾，不上傳。',
          ],
        ),
      ],
    );
  }
}

String _useOf(HealthDataKind kind) => switch (kind) {
  HealthDataKind.sleep => '記成睡眠紀錄',
  HealthDataKind.weight => '記成體重',
  HealthDataKind.waist => '記成腰圍',
  HealthDataKind.workouts => '記成運動紀錄',
  HealthDataKind.water => '記成喝水',
};

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gutter(child: SectionLabel(title)),
        for (final line in lines)
          Gutter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ReadableWidth(
                child: Text(line, style: AppTextStyles.body),
              ),
            ),
          ),
      ],
    );
  }
}
