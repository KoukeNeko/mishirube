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
      appBar: const PageAppBar(title: '隱私說明', subtitle: '你的資料去了哪裡'),
      children: [
        Gutter(
          child: const InfoBanner(
            tone: CardTone.training,
            icon: Icons.shield_outlined,
            message: '所有紀錄都存在這台裝置上。沒有帳號、沒有伺服器，我們看不到你的資料。',
          ),
        ),
        const _Section(
          title: '資料存在哪裡',
          lines: [
            '紀錄存在 App 自己的資料庫裡，只在這台裝置上。',
            '在 App 裡刪除的紀錄會先標成已刪除，所以能復原；它仍在這台裝置的資料庫裡，'
                '直到解除安裝 App，資料庫才會整個清除。',
          ],
        ),
        _Section(
          title: '健康資料（$platform）',
          lines: [
            '只在你按「連接」並允許之後才讀取，讀的是最近 30 天，之後每次打開 App 會再讀一次。',
            '只讀取，從不寫入：App 不會新增、修改或刪除 $platform 裡的任何資料。',
            '讀進來的資料只用來變成你在這裡的紀錄，顯示在紀錄、今天與趨勢裡。'
                '不會送出這台裝置，不會給 AI，也不會用於廣告。',
            '你可以隨時在「我的 > 資料來源」中斷連接。已經讀進來的紀錄會保留，想刪的話在紀錄裡刪除。',
          ],
        ),
        if (kinds.isNotEmpty) ...[
          Gutter(child: const SectionLabel('會讀取的類別')),
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
            '預設不使用任何 AI，沒選之前什麼都不會送出。',
            '選 Apple Intelligence 時，模型在手機上執行，資料不會離開這支手機。',
            '選雲端 AI（Ollama Cloud、Google AI Studio、Anthropic、Azure AI Foundry、'
                'Microsoft 365 Copilot，或你自己填的 OpenAI 相容位址）時，'
                '只會送出你打的那段文字，或從照片辨識出的文字；'
                '第一次送出前會先問你，之後可以在「我的 > AI」撤回。'
                '其他紀錄和健康資料都不會送出。',
            'Google AI Studio 的免費額度另有一點要知道：Google 的條款寫明那些內容會用於改進'
                '他們的產品，且可能由人工審閱。設定頁上也寫著這件事。',
            '掃描營養標示時，照片在手機上辨識文字，照片本身不會送出；'
                '選 Ollama Cloud 時送出的是辨識出的文字。',
            'AI 只產生草稿，你確認之後才會記錄。',
          ],
        ),
        const _Section(
          title: '金鑰、匯出與備份',
          lines: [
            'Ollama 的 API 金鑰存在系統的安全儲存區（iPhone 的鑰匙圈、Android 的 Keystore），'
                '不在資料庫裡，也不會跟著匯出。',
            '只有你在「我的 > 匯出」按下匯出時，才會在 App 自己的資料夾建立檔案；不會上傳到任何地方。',
          ],
        ),
      ],
    );
  }
}

String _useOf(HealthDataKind kind) => switch (kind) {
  HealthDataKind.sleep => '記成睡眠紀錄',
  HealthDataKind.weight => '記成體重',
  HealthDataKind.waist => '記成腰圍量測',
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
              child: Text(line, style: AppTextStyles.body),
            ),
          ),
      ],
    );
  }
}
