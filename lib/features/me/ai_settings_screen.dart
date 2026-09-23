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
      hint: '貼上金鑰，留空即刪除',
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
      hint: store.aiProvider == AiProviderKind.azureAiFoundry
          ? 'Azure AI Foundry 資源網址'
          : 'https://…/v1',
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
        message: models.isEmpty ? '讀不到模型清單，請直接輸入名稱。' : null,
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
        hint: store.aiProvider == AiProviderKind.azureAiFoundry
            ? '部署名稱'
            : '例如 gemini-3.8-flash',
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
              '以公司或學校帳號登入。',
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
        message: '下次使用雲端 AI 前會再次詢問。',
        actions: [
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
          DialogAction(
            label: '撤回同意',
            tone: DialogTone.destructive,
            onTap: () {
              store
                ..setCloudConsent(false)
                ..setPhotoConsent(false);
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
        Gutter(child: const SectionLabel('服務')),
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
            if (provider == null) return const SizedBox.shrink();
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
                              ? '未設定'
                              : store.aiEndpoint,
                          onTap: _editEndpoint,
                        ),
                      if (provider.needsSignIn) ...[
                        NavRow(
                          title: '用戶端 ID',
                          subtitle: store.aiClientId.isEmpty
                              ? '未設定'
                              : store.aiClientId,
                          onTap: _editClientId,
                        ),
                        NavRow(
                          title: '租用戶',
                          subtitle: store.aiTenant.isEmpty
                              ? 'organizations'
                              : store.aiTenant,
                          onTap: _editTenant,
                        ),
                        NavRow(
                          title: hasKey ? '已登入' : '登入',
                          subtitle: _isSigningIn
                              ? '等待瀏覽器登入…'
                              : hasKey
                              ? '重新登入'
                              : null,
                          onTap: _isSigningIn || store.aiClientId.isEmpty
                              ? null
                              : _signIn,
                        ),
                      ],
                      if (provider.needsKey)
                        NavRow(
                          title: 'API 金鑰',
                          subtitle: hasKey
                              ? '已設定'
                              : [
                                  '未設定',
                                  ?_keySource(provider),
                                ].join(' · '),
                          onTap: _editKey,
                        ),
                      if (provider.hasModelChoice)
                        NavRow(
                          title: '模型',
                          subtitle: _isLoadingModels
                              ? '讀取模型…'
                              : store.aiModel.isEmpty
                              ? '未選擇'
                              : store.aiModel,
                          onTap: _isLoadingModels ? null : _editModel,
                        ),
                      if (store.hasCloudConsent || store.hasPhotoConsent)
                        NavRow(
                          title: '撤回同意',
                          subtitle: switch ((
                            store.hasCloudConsent,
                            store.hasPhotoConsent,
                          )) {
                            (true, true) => '目前已同意送出文字與照片',
                            (true, false) => '目前已同意送出文字',
                            _ => '目前已同意送出照片',
                          },
                          onTap: _revokeConsent,
                        ),
                    ],
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
  AiAvailability.available => '在裝置上執行',
  AiAvailability.deviceNotEligible => '這台裝置不支援 Apple Intelligence',
  AiAvailability.notEnabled => '到「設定 > Apple Intelligence 與 Siri」開啟',
  AiAvailability.modelNotReady => '模型下載中',
  AiAvailability.needsKey ||
  AiAvailability.unavailable => '需要 iOS 26 以上且支援 Apple Intelligence',
};

/// Where a provider's key is created, for a row that has none yet.
String? _keySource(AiProviderKind provider) => switch (provider) {
  AiProviderKind.ollamaCloud => 'ollama.com',
  AiProviderKind.googleAiStudio => 'aistudio.google.com',
  AiProviderKind.anthropic => 'console.anthropic.com',
  AiProviderKind.azureAiFoundry => 'Azure 入口網站',
  _ => null,
};

/// What a provider's own terms mean for a health log.
String? _warningOf(AiProviderKind provider) => switch (provider) {
  AiProviderKind.microsoftCopilot =>
    'Beta API，不支援正式產品。需要公司或學校帳號、Microsoft 365 Copilot 授權'
        '與 Entra 應用程式註冊。',
  AiProviderKind.googleAiStudio =>
    '免費額度的內容可能被 Google 用於改進產品並經人工審閱。請使用已啟用計費的金鑰。',
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
          '只送出輸入的文字或從照片辨識出的文字，不送出照片與其他紀錄。'
          '可在「我的 > AI」撤回。',
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

/// Asks before the first food photo goes to a cloud provider: agreeing
/// to send text never covered a photo.
Future<bool> askPhotoConsent(BuildContext context) async {
  final store = AppStoreScope.read(context);
  final provider = store.aiProvider?.label ?? '雲端 AI';
  final agreed = await showAppDialog<bool>(
    context,
    AppDialog(
      title: '送出食物照片到 $provider？',
      message:
          '只送出這張照片與補充說明，先移除照片裡的位置與拍攝資訊，'
          '不保存照片。可在「我的 > AI」撤回。',
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
  store.setPhotoConsent(true);
  return true;
}

/// Why a request produced no draft, in the words the screens show.
String aiFailureMessage(AiFailure failure) => switch (failure) {
  AiFailure.unavailable => 'AI 還不能用，到「我的 > AI」設定。',
  AiFailure.needsConsent => '未同意送出文字。',
  AiFailure.authentication => '金鑰無效或沒有權限，到「我的 > AI」重新設定。',
  AiFailure.rateLimited => '請求太頻繁或額度用完，稍後再試。',
  AiFailure.network => '連不上網路，稍後再試。',
  AiFailure.providerError => 'AI 服務出了問題，稍後再試。',
  AiFailure.unreadable => 'AI 的回覆無法解讀，再試一次。',
  AiFailure.noText => '照片裡讀不到文字，換一張清楚的正面照片。',
  AiFailure.needsPhotoConsent => '未同意送出照片。',
  AiFailure.photoUnsupported => '目前的 AI 不能讀照片，到「我的 > AI」換一個。',
  AiFailure.noFood => '照片裡看不到食物或飲料，換一張再試。',
  AiFailure.photoFormat => '這張照片的格式無法讀取，換一張再試。',
};
