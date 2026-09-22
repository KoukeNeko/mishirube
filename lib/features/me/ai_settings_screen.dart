import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// Which AI drafts come from, and what it needs: nothing for Apple's
/// on-device model, a key and a model name for Ollama Cloud, and the
/// user's say-so before anything they type leaves the phone.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  /// Read once per visit and after every change here: availability asks
  /// the system or the keychain, which a rebuild should not repeat.
  late Future<(AiAvailability, bool)> _status = _readStatus();

  Future<(AiAvailability, bool)> _readStatus() async {
    final store = AppStoreScope.read(context);
    return (
      await store.aiAvailability(AiProviderKind.appleOnDevice),
      await store.hasOllamaKey(),
    );
  }

  void _refresh() => setState(() => _status = _readStatus());

  Future<void> _editKey() async {
    final store = AppStoreScope.read(context);
    final key = await showTextDialog(
      context,
      title: 'Ollama API 金鑰',
      hint: '貼上金鑰；留空就刪除',
    );
    if (key == null) return;
    await store.setOllamaKey(key);
    if (mounted) _refresh();
  }

  Future<void> _editModel() async {
    final store = AppStoreScope.read(context);
    final model = await showTextDialog(
      context,
      title: '模型',
      initial: store.ollamaModel,
      hint: 'gemma4:31b',
    );
    if (model != null) store.setOllamaModel(model);
  }

  Future<void> _revokeConsent() async {
    final store = AppStoreScope.read(context);
    await showAppDialog<void>(
      context,
      AppDialog(
        title: '撤回同意？',
        message: '之後用 Ollama Cloud 前會再問你一次。',
        actions: [
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
          DialogAction(
            label: '撤回',
            tone: DialogTone.destructive,
            onTap: () {
              store.setCloudConsent(false);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final provider = store.aiProvider;
    return DetailPage(
      appBar: const PageAppBar(title: 'AI'),
      children: [
        Gutter(
          child: const InfoBanner(
            icon: Icons.auto_awesome_outlined,
            message: 'AI 只幫你寫草稿，你確認之後才會記錄。',
          ),
        ),
        Gutter(child: const SectionLabel('用哪一個')),
        Gutter(
          child: ChipWrap(
            options: AiProviderKind.values,
            labelOf: (kind) => kind.label,
            isSelected: (kind) => kind == provider,
            onTap: store.setAiProvider,
          ),
        ),
        FutureBuilder(
          future: _status,
          builder: (context, snapshot) {
            final (apple, hasKey) = snapshot.data ?? (null, false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: switch (provider) {
                null => [
                  Gutter(
                    child: const Text(
                      '還沒選。沒選之前不會送出任何東西。',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
                AiProviderKind.appleOnDevice => [
                  Gutter(
                    child: Text(
                      _appleStatus(apple),
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
                AiProviderKind.ollamaCloud => [
                  Gutter(
                    child: GroupedCard(
                      children: [
                        NavRow(
                          title: 'API 金鑰',
                          subtitle: hasKey ? '已設定，存在系統鑰匙圈' : '還沒設定',
                          onTap: _editKey,
                        ),
                        NavRow(
                          title: '模型',
                          subtitle: store.ollamaModel,
                          onTap: _editModel,
                        ),
                        if (store.hasCloudConsent)
                          NavRow(
                            title: '已同意送出描述',
                            subtitle: '點一下撤回',
                            onTap: _revokeConsent,
                          ),
                      ],
                    ),
                  ),
                  Gutter(
                    child: const Text(
                      '會送出的只有你打的那段描述，送到 Ollama（ollama.com），'
                      '不會送出其他紀錄。金鑰在 ollama.com 的帳號設定建立。',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              },
            );
          },
        ),
      ],
    );
  }
}

String _appleStatus(AiAvailability? availability) => switch (availability) {
  null => '檢查中…',
  AiAvailability.available => '可以用。在手機上執行，資料不會離開這支手機。',
  AiAvailability.deviceNotEligible => '這支手機不支援 Apple Intelligence。',
  AiAvailability.notEnabled => '請到「設定 > Apple Intelligence 與 Siri」開啟。',
  AiAvailability.modelNotReady => '模型還在下載，稍後再試。',
  AiAvailability.needsKey ||
  AiAvailability.unavailable => '需要 iOS 26 以上、支援 Apple Intelligence 的 iPhone。',
};

/// Asked once, before the first request that leaves the phone; true when
/// the user agreed, which is then remembered.
Future<bool> askCloudConsent(BuildContext context) async {
  final store = AppStoreScope.read(context);
  final agreed = await showAppDialog<bool>(
    context,
    AppDialog(
      title: '送到 Ollama Cloud？',
      message:
          '你打的文字、或從照片辨識出的文字會送到 Ollama（ollama.com）產生草稿。'
          '照片本身和其他紀錄不會送出。之後可以在「我的 > AI」撤回。',
      actions: [
        DialogAction(
          label: '取消',
          onTap: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: '同意並送出',
          tone: DialogTone.primary,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (agreed != true) return false;
  store.setCloudConsent(true);
  return true;
}

/// Why a request produced no draft, in the words the screens show.
String aiFailureMessage(AiFailure failure) => switch (failure) {
  AiFailure.unavailable => 'AI 現在不能用，到「我的 > AI」看看設定。',
  AiFailure.needsConsent => '還沒同意送出文字。',
  AiFailure.authentication => 'Ollama 金鑰無效，到「我的 > AI」重新設定。',
  AiFailure.rateLimited => '請求太頻繁或額度用完了，稍後再試。',
  AiFailure.network => '連不上網路，稍後再試。',
  AiFailure.providerError => 'AI 服務出了問題，稍後再試。',
  AiFailure.unreadable => '看不懂 AI 的回答，換個說法或換張照片再試一次。',
  AiFailure.noText => '照片裡讀不到文字，換一張清楚、正面的照片再試。',
};
