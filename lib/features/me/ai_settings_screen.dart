import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

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
      title: context.l10n.apiKeyTitle(
        provider: store.aiProvider?.labelIn(context.l10n) ?? '',
      ),
      hint: context.l10n.apiKeyHint,
    );
    if (key == null) return;
    await store.setAiKey(key);
    if (mounted) _refresh();
  }

  Future<void> _editEndpoint() async {
    final store = AppStoreScope.read(context);
    final address = await showTextDialog(
      context,
      title: context.l10n.apiEndpoint,
      initial: store.aiEndpoint,
      hint: store.aiProvider == AiProviderKind.azureAiFoundry
          ? context.l10n.azureResourceUrl
          : 'https://…/v1',
    );
    if (address != null) store.setAiEndpoint(address);
  }

  /// The models the provider offers, to pick from; typing a name stays
  /// possible for one the list does not have yet.
  Future<void> _editModel() async {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    final l10n = context.l10n;
    setState(() => _isLoadingModels = true);
    List<String> models;
    try {
      models = await store.aiModels();
    } on AiException catch (error) {
      models = const [];
      toast.show(
        aiFailureMessage(l10n, error.failure),
        kind: ToastKind.warning,
      );
    } finally {
      if (mounted) setState(() => _isLoadingModels = false);
    }
    if (!mounted) return;
    final chosen = await showAppDialog<String>(
      context,
      AppDialog(
        title: context.l10n.modelLabel,
        message: models.isEmpty ? context.l10n.modelListUnavailable : null,
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
            label: context.l10n.typeOwn,
            onTap: () => Navigator.of(context).pop(_typeModel),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    if (chosen == _typeModel) {
      final typed = await showTextDialog(
        context,
        title: context.l10n.modelLabel,
        initial: store.aiModel,
        hint: store.aiProvider == AiProviderKind.azureAiFoundry
            ? context.l10n.deploymentName
            : context.l10n.modelHint,
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
    final l10n = context.l10n;
    setState(() => _isSigningIn = true);
    try {
      final prompt = await store.startAiSignIn();
      if (!mounted) return;
      final waiting = store.finishAiSignIn(prompt);
      await showAppDialog<void>(
        context,
        AppDialog(
          title: l10n.signInInBrowser,
          message: l10n.signInInstructions(
            uri: prompt.verificationUri,
            code: prompt.userCode,
          ),
          actions: [
            DialogAction(
              label: l10n.copyCode,
              onTap: () {
                Clipboard.setData(ClipboardData(text: prompt.userCode));
                Navigator.of(context).pop();
              },
            ),
            DialogAction(
              label: l10n.okAction,
              tone: DialogTone.primary,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      await waiting;
      if (!mounted) return;
      toast.show(l10n.signedInCopilot);
    } on AiException catch (error) {
      toast.show(
        aiFailureMessage(l10n, error.failure),
        kind: ToastKind.warning,
      );
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
      title: context.l10n.clientId,
      initial: store.aiClientId,
      hint: context.l10n.clientIdHint,
    );
    if (id != null) store.setAiClientId(id);
  }

  Future<void> _editTenant() async {
    final store = AppStoreScope.read(context);
    final tenant = await showTextDialog(
      context,
      title: context.l10n.tenant,
      initial: store.aiTenant,
      hint: context.l10n.tenantHint,
    );
    if (tenant != null) store.setAiTenant(tenant);
  }

  Future<void> _revokeConsent() async {
    final store = AppStoreScope.read(context);
    await showAppDialog<void>(
      context,
      AppDialog(
        title: context.l10n.revokeConsentTitle,
        message: context.l10n.revokeConsentMessage,
        actions: [
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
          DialogAction(
            label: context.l10n.revokeConsent,
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
        Gutter(child: SectionLabel(context.l10n.serviceSection)),
        Gutter(
          child: ChipWrap(
            options: AiProviderKind.values,
            labelOf: (kind) => kind.labelIn(context.l10n),
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
                child: Text(
                  _appleStatus(context.l10n, apple),
                  style: AppTextStyles.caption,
                ),
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
                          title: context.l10n.apiEndpoint,
                          subtitle: store.aiEndpoint.isEmpty
                              ? context.l10n.notSet
                              : store.aiEndpoint,
                          onTap: _editEndpoint,
                        ),
                      if (provider.needsSignIn) ...[
                        NavRow(
                          title: context.l10n.clientId,
                          subtitle: store.aiClientId.isEmpty
                              ? context.l10n.notSet
                              : store.aiClientId,
                          onTap: _editClientId,
                        ),
                        NavRow(
                          title: context.l10n.tenant,
                          subtitle: store.aiTenant.isEmpty
                              ? 'organizations'
                              : store.aiTenant,
                          onTap: _editTenant,
                        ),
                        NavRow(
                          title: hasKey
                              ? context.l10n.signedIn
                              : context.l10n.signIn,
                          subtitle: _isSigningIn
                              ? context.l10n.waitingForBrowser
                              : hasKey
                              ? context.l10n.signInAgain
                              : null,
                          onTap: _isSigningIn || store.aiClientId.isEmpty
                              ? null
                              : _signIn,
                        ),
                      ],
                      if (provider.needsKey)
                        NavRow(
                          title: context.l10n.apiKey,
                          subtitle: hasKey
                              ? context.l10n.isSet
                              : [
                                  context.l10n.notSet,
                                  ?_keySource(context.l10n, provider),
                                ].join(' · '),
                          onTap: _editKey,
                        ),
                      if (provider.hasModelChoice)
                        NavRow(
                          title: context.l10n.modelLabel,
                          subtitle: _isLoadingModels
                              ? context.l10n.loadingModels
                              : store.aiModel.isEmpty
                              ? context.l10n.notChosen
                              : store.aiModel,
                          onTap: _isLoadingModels ? null : _editModel,
                        ),
                      if (store.hasCloudConsent || store.hasPhotoConsent)
                        NavRow(
                          title: context.l10n.revokeConsent,
                          subtitle: switch ((
                            store.hasCloudConsent,
                            store.hasPhotoConsent,
                          )) {
                            (true, true) => context.l10n.consentTextAndPhotos,
                            (true, false) => context.l10n.consentText,
                            _ => context.l10n.consentPhotos,
                          },
                          onTap: _revokeConsent,
                        ),
                    ],
                  ),
                ),
                if (_warningOf(context.l10n, provider) case final warning?)
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

String _appleStatus(AppLocalizations l10n, AiAvailability? availability) =>
    switch (availability) {
      null => l10n.checkingEllipsis,
      AiAvailability.available => l10n.privacyAppleIntelligence,
      AiAvailability.deviceNotEligible => l10n.appleNotEligible,
      AiAvailability.notEnabled => l10n.appleNotEnabled,
      AiAvailability.modelNotReady => l10n.appleModelNotReady,
      AiAvailability.needsKey ||
      AiAvailability.unavailable => l10n.appleUnavailable,
    };

/// Where a provider's key is created, for a row that has none yet.
String? _keySource(AppLocalizations l10n, AiProviderKind provider) =>
    switch (provider) {
      AiProviderKind.ollamaCloud => 'ollama.com',
      AiProviderKind.googleAiStudio => 'aistudio.google.com',
      AiProviderKind.anthropic => 'console.anthropic.com',
      AiProviderKind.azureAiFoundry => l10n.azurePortal,
      _ => null,
    };

/// What a provider's own terms mean for a health log.
String? _warningOf(AppLocalizations l10n, AiProviderKind provider) =>
    switch (provider) {
      AiProviderKind.microsoftCopilot => l10n.copilotWarning,
      AiProviderKind.googleAiStudio => l10n.googleFreeWarning,
      _ => null,
    };

/// Asked once, before the first request that leaves the phone; true when
/// the user agreed, which is then remembered.
Future<bool> askCloudConsent(BuildContext context) async {
  final store = AppStoreScope.read(context);
  final provider =
      store.aiProvider?.labelIn(context.l10n) ?? context.l10n.cloudAi;
  final agreed = await showAppDialog<bool>(
    context,
    AppDialog(
      title: context.l10n.sendToProvider(provider: provider),
      message: context.l10n.cloudConsentMessage(me: context.l10n.tabMe),
      actions: [
        DialogAction(
          label: context.l10n.commonCancel,
          onTap: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: context.l10n.agreeAndSend,
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
  final provider =
      store.aiProvider?.labelIn(context.l10n) ?? context.l10n.cloudAi;
  final agreed = await showAppDialog<bool>(
    context,
    AppDialog(
      title: context.l10n.sendPhotoToProvider(provider: provider),
      message: context.l10n.photoConsentMessage(me: context.l10n.tabMe),
      actions: [
        DialogAction(
          label: context.l10n.commonCancel,
          onTap: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: context.l10n.agreeAndSend,
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
String aiFailureMessage(AppLocalizations l10n, AiFailure failure) =>
    switch (failure) {
      AiFailure.unavailable => l10n.aiFailureUnavailable(me: l10n.tabMe),
      AiFailure.needsConsent => l10n.aiFailureNeedsConsent,
      AiFailure.authentication => l10n.aiFailureAuthentication(me: l10n.tabMe),
      AiFailure.rateLimited => l10n.aiFailureRateLimited,
      AiFailure.network => l10n.aiFailureNetwork,
      AiFailure.providerError => l10n.aiFailureProvider,
      AiFailure.unreadable => l10n.aiFailureUnreadable,
      AiFailure.needsPhotoConsent => l10n.aiFailureNeedsPhotoConsent,
      AiFailure.photoUnsupported => l10n.aiFailurePhotoUnsupported(
        me: l10n.tabMe,
      ),
      AiFailure.noFood => l10n.aiFailureNoFood,
      AiFailure.photoFormat => l10n.aiFailurePhotoFormat,
    };
