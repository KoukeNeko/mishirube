import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import 'ai_proposal_screen.dart';

const _readableData = ['訓練紀錄', '飲食紀錄', '體重與量測', '睡眠', '心情與症狀'];
const _deleteAction = '刪除資料';
const _allowedActions = ['建立紀錄草稿', '修改訓練計畫', _deleteAction];

class AiPermissionsScreen extends StatefulWidget {
  const AiPermissionsScreen({super.key});

  @override
  State<AiPermissionsScreen> createState() => _AiPermissionsScreenState();
}

class _AiPermissionsScreenState extends State<AiPermissionsScreen> {
  final Set<String> _granted = {'訓練紀錄', '飲食紀錄', '體重與量測', '建立紀錄草稿'};

  void _toggle(String permission) => setState(() {
    if (!_granted.remove(permission)) _granted.add(permission);
  });

  Widget _checkList(List<String> items) => GroupedCard(
    children: [
      for (final item in items)
        CheckRow(
          title: item,
          isChecked: _granted.contains(item),
          onChanged: (_) => _toggle(item),
          badge: item == _deleteAction
              ? const TagChip(label: '高風險', tone: TagTone.warning)
              : null,
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: 'AI 權限', subtitle: '自備金鑰 · 可隨時關閉'),
      children: [
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('提供者', style: AppTextStyles.overline),
              SizedBox(height: AppSpacing.xs),
              Text('OpenAI-compatible · 自架端點', style: AppTextStyles.pageTitle),
              SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  TagChip(label: '金鑰存在系統鑰匙圈', tone: TagTone.training),
                  TagChip(label: '不寫入資料庫、log 或匯出檔'),
                ],
              ),
            ],
          ),
        ),
        const SectionLabel('可以讀取哪些資料'),
        _checkList(_readableData),
        const Text('每次請求前，會先列出實際要送出的資料範圍。', style: AppTextStyles.caption),
        const SectionLabel('可以做哪些操作'),
        _checkList(_allowedActions),
        const Text(
          'AI 只會產生草稿。任何修改都會先顯示差異，由你確認才寫入。',
          style: AppTextStyles.caption,
        ),
        SecondaryButton(
          label: '查看修改紀錄',
          onPressed: () => pushPage(context, const AiProposalScreen()),
        ),
      ],
    );
  }
}
