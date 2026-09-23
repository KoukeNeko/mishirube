import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../me/ai_settings_screen.dart';
import 'nutrition_view_model.dart';

/// A meal in one sentence: the chosen AI drafts it, the user checks and
/// corrects it, and only then is anything logged. Given a [draft] already
/// made — a food photo's items — it opens on the check.
///
/// Pops with the logged meals, so the page that opened it can close too
/// and offer the undo, the way logging a plate does.
class DescribeMealScreen extends StatefulWidget {
  const DescribeMealScreen({super.key, this.mealType, this.draft});

  final MealType? mealType;
  final MealDraft? draft;

  @override
  State<DescribeMealScreen> createState() => _DescribeMealScreenState();
}

class _DescribeMealScreenState extends State<DescribeMealScreen> {
  late final NutritionViewModel _nutrition;
  final _text = TextEditingController();
  bool _isDrafting = false;
  AiFailure? _failure;
  MealDraft? _draft;

  /// The draft's items as the user left them: removed ones gone, typed
  /// calories in place of the model's.
  List<DraftItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
    _text.addListener(() => setState(() {}));
    if (widget.draft case final draft?) {
      _draft = draft;
      _items = draft.items;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _nutrition.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final store = AppStoreScope.read(context);
    setState(() {
      _isDrafting = true;
      _failure = null;
    });
    try {
      final draft = await store.draftMeal(_text.text.trim());
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _items = draft.items;
      });
    } on AiException catch (error) {
      if (!mounted) return;
      if (error.failure == AiFailure.needsConsent) {
        setState(() => _isDrafting = false);
        if (await _askConsent()) await _generate();
        return;
      }
      setState(() => _failure = error.failure);
    } finally {
      if (mounted) setState(() => _isDrafting = false);
    }
  }

  Future<bool> _askConsent() => askCloudConsent(context);

  Future<void> _editKcal(int index) async {
    final item = _items[index];
    final typed = await showTextDialog(
      context,
      title: '${item.name} 的熱量',
      initial: item.kcal == null ? '' : '${item.kcal}',
      hint: 'kcal',
    );
    final kcal = int.tryParse(typed?.trim() ?? '');
    if (kcal == null) return;
    setState(() => _items = [..._items]..[index] = item.copyWith(kcal: kcal));
  }

  void _remove(int index) {
    final removed = _items[index];
    setState(() => _items = [..._items]..removeAt(index));
    ToastScope.read(context).showUndo(
      '已移除「${removed.name}」',
      onUndo: () {
        if (!mounted) return;
        setState(
          () =>
              _items = [..._items]
                ..insert(index.clamp(0, _items.length), removed),
        );
      },
    );
  }

  void _log() {
    final logged = _nutrition.logDraft(
      _draft!,
      _items,
      mealType: widget.mealType,
    );
    Navigator.of(context).pop(logged);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final draft = _draft;
    return DetailPage(
      appBar: PageAppBar(
        title: widget.draft == null ? '用一句話記錄' : '照片估算',
        subtitle: store.aiProvider?.label ?? 'AI 未啟用',
      ),
      footer: draft == null
          ? PrimaryButton(
              label: _isDrafting ? '產生中…' : '產生草稿',
              onPressed:
                  _isDrafting ||
                      _text.text.trim().isEmpty ||
                      store.aiProvider == null
                  ? null
                  : _generate,
            )
          : PrimaryButton(
              label: '記錄 ${_items.length} 項',
              onPressed: _items.isEmpty ? null : _log,
            ),
      children: [
        if (store.aiProvider == null && widget.draft == null) ...[
          Gutter(
            child: const InfoBanner(
              icon: Icons.auto_awesome_outlined,
              message: '先選一個 AI 才能產生草稿。',
            ),
          ),
          Gutter(
            child: LinkText(
              label: '到「我的 > AI」設定',
              onTap: () => pushPage(context, const AiSettingsScreen()),
            ),
          ),
        ],
        if (widget.draft == null)
          Gutter(
            child: AppTextField(
              controller: _text,
              hint: '例如：早餐 蛋餅加大杯冰奶茶',
              maxLines: 3,
            ),
          ),
        if (_failure case final failure?)
          Gutter(
            child: InfoBanner(
              tone: CardTone.warning,
              message: aiFailureMessage(failure),
            ),
          ),
        if (draft != null) ...[
          if (draft.warnings.isNotEmpty)
            Gutter(
              child: InfoBanner(
                tone: CardTone.warning,
                message: draft.warnings.join('\n'),
              ),
            ),
          Gutter(child: const SectionLabel('草稿')),
          for (final (index, item) in _items.indexed)
            Gutter(
              child: SwipeAction(
                key: ValueKey('${item.name}$index'),
                label: '移除',
                semanticLabel: '移除「${item.name}」',
                onAction: () => _remove(index),
                child: NavCard(
                  title: item.name,
                  subtitle:
                      '${item.amount} · '
                      '${formatKcalOrDash(item.kcal)} kcal',
                  onTap: () => _editKcal(index),
                ),
              ),
            ),
          Gutter(
            child: Text(
              '${draft.provider.label}（${draft.model}）估計',
              style: AppTextStyles.caption,
            ),
          ),
          if (widget.draft == null)
            Gutter(
              child: LinkText(
                label: '重新產生',
                onTap: () => setState(() => _draft = null),
              ),
            ),
        ],
      ],
    );
  }
}
