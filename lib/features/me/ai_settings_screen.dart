import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// Which AI drafts come from and what it needs: nothing for Apple's
/// on-device model, a key for the others, an address as well for an
/// OpenAI-compatible one, and the user's say-so before anything they
/// type leaves the phone.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  /// Read once per visit and after every change here: availability asks
  /// the system or the keychain, which a rebuild should not repeat.
  late Future<(AiAvailability, bool)> _status = _readStatus();
  bool _isLoadingModels = false;
  bool _isSigningIn = false;

  Future<(AiAvailability, bool)> _readStatus() async {
    final store = AppStoreScope.read(context);
    return (
      await store.aiAvailability(AiProviderKind.appleOnDevice),
      await store.hasAiKey(),
    );
  }

  void _refresh() => setState(() => _status = _readStatus());

  Future<void> _editKey() async {
    final store = AppStoreScope.read(context);
    final key = await showTextDialog(
      context,
      title: '${store.aiProvider?.label ?? ''} API 金鑰',
      hint: '貼上金鑰；留空就刪除',
    );
    if (key == null) return;
    await store.setAiKey(key);
    if (mounted) _refresh();
  }

  Future<void> _editEndpoint() async {
    final store = AppStoreScope.read(context);
    final address = await showTextDialog(
      context,
      title: 'API 位址',
      initial: store.aiEndpoint,
      hint: 'https://…/v1',
    );
    if (address != null) store.setAiEndpoint(address);
  }

  /// The models the provider offers, to pick from; typing a name stays
  /// possible for one the list does not have yet.
  Future<void> _editModel() async {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    setState(() => _isLoadingModels = true);
    List<String> models;
    try {
      models = await store.aiModels();
    } on AiException catch (error) {
      models = const [];
      toast.show(aiFailureMessage(error.failure), kind: ToastKind.warning);
    } finally {
      if (mounted) setState(() => _isLoadingModels = false);
    }
    if (!mounted) return;
    final chosen = await showAppDialog<String>(
      context,
      AppDialog(
        title: '模型',
        message: models.isEmpty ? '沒有讀到可用的模型清單，可以直接輸入名稱。' : null,
        isChoiceList: true,
        actions: [
          for (final model in models)
            DialogAction(
              icon: model == store.aiModel ? Icons.check : null,
              label: model,
              onTap: () => Navigator.of(context).pop(model),
            ),
          DialogAction(
            icon: Icons.keyboard_outlined,
            label: '自己輸入',
            onTap: () => Navigator.of(context).pop(_typeModel),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    if (chosen == _typeModel) {
      final typed = await showTextDialog(
        context,
        title: '模型',
        initial: store.aiModel,
        hint: '例如 gemini-3.8-flash',
      );
      if (typed != null) store.setAiModel(typed);
      return;
    }
    store.setAiModel(chosen);
  }

  /// Not a model name: the choice that opens the text field.
  static const _typeModel = '';

  /// Signing in to Microsoft 365 Copilot: a code to type on Microsoft's
  /// page, then the app waits for the user to finish.
  Future<void> _signIn() async {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    setState(() => _isSigningIn = true);
    try {
      final prompt = await store.startAiSignIn();
      if (!mounted) return;
      final waiting = store.finishAiSignIn(prompt);
      await showAppDialog<void>(
        context,
        AppDialog(
          title: '在瀏覽器登入',
          message:
              '到 ${prompt.verificationUri} 輸入代碼 ${prompt.userCode}，'
              '用你的公司或學校帳號登入。完成後這裡會自己接上。',
          actions: [
            DialogAction(
              label: '複製代碼',
              onTap: () {
                Clipboard.setData(ClipboardData(text: prompt.userCode));
                Navigator.of(context).pop();
              },
            ),
            DialogAction(
              label: '好',
              tone: DialogTone.primary,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      await waiting;
      if (!mounted) return;
      toast.show('已登入 Microsoft 365 Copilot');
    } on AiException catch (error) {
      toast.show(aiFailureMessage(error.failure), kind: ToastKind.warning);
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
        _refresh();
      }
    }
  }

  Future<void> _editClientId() async {
    final store = AppStoreScope.read(context);
    final id = await showTextDialog(
      context,
      title: '用戶端 ID',
      initial: store.aiClientId,
      hint: 'Entra 應用程式註冊的 Application (client) ID',
    );
    if (id != null) store.setAiClientId(id);
  }

  Future<void> _editTenant() async {
    final store = AppStoreScope.read(context);
    final tenant = await showTextDialog(
      context,
      title: '租用戶',
      initial: store.aiTenant,
      hint: '留空代表 organizations',
    );
    if (tenant != null) store.setAiTenant(tenant);
  }

  Future<void> _revokeConsent() async {
    final store = AppStoreScope.read(context);
    await showAppDialog<void>(
      context,
      AppDialog(
        title: '撤回同意？',
        message: '之後用雲端 AI 前會再問你一次。',
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
            onTap: (kind) {
              store.setAiProvider(kind);
              _refresh();
            },
          ),
        ),
        FutureBuilder(
          future: _status,
          builder: (context, snapshot) {
            final (apple, hasKey) = snapshot.data ?? (null, false);
            if (provider == null) {
              return Gutter(
                child: const Text(
                  '還沒選。沒選之前不會送出任何東西。',
                  style: AppTextStyles.caption,
                ),
              );
            }
            if (provider == AiProviderKind.appleOnDevice) {
              return Gutter(
                child: Text(_appleStatus(apple), style: AppTextStyles.caption),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Gutter(
                  child: GroupedCard(
                    children: [
                      if (provider.needsEndpoint)
                        NavRow(
                          title: 'API 位址',
                          subtitle: store.aiEndpoint.isEmpty
                              ? '還沒設定，例如 https://…/v1'
                              : store.aiEndpoint,
                          onTap: _editEndpoint,
                        ),
                      if (provider.needsSignIn) ...[
                        NavRow(
                          title: '用戶端 ID',
                          subtitle: store.aiClientId.isEmpty
                              ? '還沒設定'
                              : store.aiClientId,
                          onTap: _editClientId,
                        ),
                        NavRow(
                          title: '租用戶',
                          subtitle: store.aiTenant.isEmpty
                              ? 'organizations（任何公司或學校帳號）'
                              : store.aiTenant,
                          onTap: _editTenant,
                        ),
                        NavRow(
                          title: hasKey ? '已登入' : '登入',
                          subtitle: _isSigningIn
                              ? '等待你在瀏覽器完成登入…'
                              : hasKey
                              ? '點一下重新登入'
                              : '用公司或學校帳號登入',
                          onTap: _isSigningIn || store.aiClientId.isEmpty
                              ? null
                              : _signIn,
                        ),
                      ],
                      if (provider.needsKey)
                        NavRow(
                          title: 'API 金鑰',
                          subtitle: hasKey ? '已設定，存在系統鑰匙圈' : '還沒設定',
                          onTap: _editKey,
                        ),
                      if (provider.hasModelChoice)
                        NavRow(
                          title: '模型',
                          subtitle: _isLoadingModels
                              ? '讀取可用的模型…'
                              : store.aiModel.isEmpty
                              ? '還沒選'
                              : store.aiModel,
                          onTap: _isLoadingModels ? null : _editModel,
                        ),
                      if (store.hasCloudConsent)
                        NavRow(
                          title: '已同意送出文字',
                          subtitle: '點一下撤回',
                          onTap: _revokeConsent,
                        ),
                    ],
                  ),
                ),
                Gutter(
                  child: Text(
                    _cloudNote(provider),
                    style: AppTextStyles.caption,
                  ),
                ),
                if (_warningOf(provider) case final warning?)
                  Gutter(
                    child: InfoBanner(tone: CardTone.warning, message: warning),
                  ),
              ],
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

/// What is sent, and where the key comes from.
String _cloudNote(AiProviderKind provider) {
  final where = switch (provider) {
    AiProviderKind.ollamaCloud => '金鑰在 ollama.com 的帳號設定建立。',
    AiProviderKind.googleAiStudio => '金鑰在 aistudio.google.com 建立。',
    AiProviderKind.anthropic => '金鑰在 console.anthropic.com 建立。',
    AiProviderKind.azureAiFoundry =>
      '位址是你的 Azure AI Foundry 資源網址，模型填部署名稱；金鑰在 Azure 入口網站取得。',
    AiProviderKind.microsoftCopilot =>
      '需要公司或學校帳號、Microsoft 365 Copilot 授權，以及你自己在 Entra 註冊的應用程式。',
    AiProviderKind.openAiCompatible => '填服務商給的 API 位址與金鑰。',
    AiProviderKind.appleOnDevice => '',
  };
  return '會送出的只有你打的文字，或從照片辨識出的文字；照片和其他紀錄不會送出。$where';
}

/// What a provider's own terms mean for a health log.
String? _warningOf(AiProviderKind provider) => switch (provider) {
  AiProviderKind.microsoftCopilot =>
    'Microsoft 的 Copilot Chat API 目前是 beta，官方寫明不支援用在正式產品，'
        '而且會依你公司的權限設定存取資料。個人的 Microsoft 帳號不能用。',
  AiProviderKind.googleAiStudio =>
    'Google 的條款寫明：免費額度送出的內容會用來改進 Google 的產品，'
        '可能由人工審閱，官方也要求不要送出個人或敏感資訊。'
        '要記自己的飲食，請改用已啟用計費的付費專案金鑰。',
  _ => null,
};

/// Asked once, before the first request that leaves the phone; true when
/// the user agreed, which is then remembered.
Future<bool> askCloudConsent(BuildContext context) async {
  final store = AppStoreScope.read(context);
  final provider = store.aiProvider?.label ?? '雲端 AI';
  final agreed = await showAppDialog<bool>(
    context,
    AppDialog(
      title: '送到 $provider？',
      message:
          '你打的文字、或從照片辨識出的文字會送到 $provider 產生草稿。'
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
  AiFailure.authentication => '金鑰無效或沒有權限，到「我的 > AI」重新設定。',
  AiFailure.rateLimited => '請求太頻繁或額度用完了，稍後再試。',
  AiFailure.network => '連不上網路，稍後再試。',
  AiFailure.providerError => 'AI 服務出了問題，稍後再試。',
  AiFailure.unreadable => '看不懂 AI 的回答，換個說法或換張照片再試一次。',
  AiFailure.noText => '照片裡讀不到文字，換一張清楚、正面的照片再試。',
};
