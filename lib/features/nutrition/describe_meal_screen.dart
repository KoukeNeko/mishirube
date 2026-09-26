import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../me/ai_draft_parts.dart';
import '../me/ai_settings_screen.dart';
import 'nutrition_view_model.dart';

/// A meal in one sentence: the chosen AI drafts it, the user checks and
/// corrects it, and only then is anything logged. Given a [draft] already
/// made — a food photo's items — it opens on the check; given a
/// [photoPath], it drafts from that photo as it opens.
///
/// Pops with the logged meals, so the page that opened it can close too
/// and offer the undo, the way logging a plate does.
class DescribeMealScreen extends StatefulWidget {
  const DescribeMealScreen({
    super.key,
    this.mealType,
    this.draft,
    this.photoPath,
    this.at,
  });

  final MealType? mealType;
  final MealDraft? draft;
  final String? photoPath;

  /// When what is logged was eaten; now when null.
  final DateTime? at;

  bool get _isPhoto => draft != null || photoPath != null;

  @override
  State<DescribeMealScreen> createState() => _DescribeMealScreenState();
}

/// Tall enough to recognise the plate by, short enough to leave the
/// draft on screen.
const _photoHeight = 200.0;

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
    if (widget.photoPath != null) {
      _isDrafting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
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
      final draft = switch (widget.photoPath) {
        final path? => await store.draftMealPhoto(path),
        null => await store.draftMeal(_text.text.trim()),
      };
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
      if (error.failure == AiFailure.needsPhotoConsent) {
        setState(() => _isDrafting = false);
        if (await askPhotoConsent(context)) await _generate();
        return;
      }
      setState(() => _failure = error.failure);
    } finally {
      if (mounted) setState(() => _isDrafting = false);
    }
  }

  Future<bool> _askConsent() => askCloudConsent(context);

  /// Corrects the model's figures for one item.
  Future<void> _editFigures(int index) async {
    final edited = await showAppDialog<DraftItem>(
      context,
      _FiguresDialog(item: _items[index]),
    );
    if (edited == null || !mounted) return;
    setState(() => _items = [..._items]..[index] = edited);
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

  /// Several items are one meal or several, as the user says. A draft
  /// handed over from 新增食物 was already split there.
  Future<void> _log() async {
    var asOneMeal = false;
    if (_items.length > 1 && widget.draft == null) {
      final choice = await showAppDialog<bool>(
        context,
        AppDialog(
          title: '${_items.length} 項',
          message: _items.map((item) => item.name).join('、'),
          actions: [
            DialogAction(
              label: '合併成一餐',
              onTap: () => Navigator.of(context).pop(true),
            ),
            DialogAction(
              label: '逐項記錄',
              tone: DialogTone.primary,
              onTap: () => Navigator.of(context).pop(false),
            ),
            DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      asOneMeal = choice;
    }
    final logged = _nutrition.logDraft(
      _draft!,
      _items,
      mealType: widget.mealType,
      asOneMeal: asOneMeal,
      at: widget.at,
    );
    Navigator.of(context).pop(logged);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final draft = _draft;
    return DetailPage(
      appBar: PageAppBar(
        title: widget._isPhoto ? '照片估算' : '用一句話記錄',
        subtitle: currentAiLabel(store),
      ),
      footer: draft == null
          ? DraftButton(
              isDrafting: _isDrafting,
              label: widget.photoPath != null ? '重試' : '產生草稿',
              onPressed:
                  (widget.photoPath == null && _text.text.trim().isEmpty) ||
                      store.aiProvider == null
                  ? null
                  : _generate,
            )
          : PrimaryButton(
              label: '記錄 ${_items.length} 項',
              onPressed: _items.isEmpty ? null : _log,
            ),
      children: [
        if (store.aiProvider == null && !widget._isPhoto) ...[
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
        if (widget.photoPath case final path?)
          Gutter(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Image.file(
                File(path),
                height: _photoHeight,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: '食物照片',
              ),
            ),
          ),
        if (!widget._isPhoto)
          Gutter(
            child: DescribeField(controller: _text, hint: '例如：早餐 蛋餅加大杯冰奶茶'),
          ),
        if (_failure case final failure?)
          Gutter(child: AiFailureBanner(failure: failure)),
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
                  detail: _macrosOf(item),
                  onTap: () => _editFigures(index),
                ),
              ),
            ),
          Gutter(
            child: DraftAttribution(
              label: aiLabel(draft.provider, draft.model),
            ),
          ),
          if (!widget._isPhoto)
            Gutter(
              child: RewriteLink(onTap: () => setState(() => _draft = null)),
            ),
        ],
      ],
    );
  }
}

/// `蛋白質 12 g · 碳水化合物 40 g · 脂肪 9 g`, a dash for a figure the
/// model did not give; then, on a line of its own, whatever else a label
/// gave: `糖 14.4 g · 鈉 79 mg · 鈣 667 mg`.
String _macrosOf(DraftItem item) {
  String grams(int? value) => value == null ? '—' : '$value g';
  final more = [
    if (item.fibreGrams case final fibre?) '${MacroLabel.fibre} $fibre g',
    for (final MapEntry(key: nutrient, value: amount) in item.nutrients.entries)
      '${nutrient.label} ${nutrient.format(amount)}',
  ];
  return [
    [
      '${MacroLabel.protein} ${grams(item.proteinGrams)}',
      '${MacroLabel.carb} ${grams(item.carbGrams)}',
      '${MacroLabel.fat} ${grams(item.fatGrams)}',
    ].join(' · '),
    if (more.isNotEmpty) more.join(' · '),
  ].join('\n');
}

/// One item's energy and macronutrients, as the model gave them, to
/// correct. Owns its fields, so they outlive the dialog's closing. A
/// field left empty is a figure nobody knows, not zero.
class _FiguresDialog extends StatefulWidget {
  const _FiguresDialog({required this.item});

  final DraftItem item;

  @override
  State<_FiguresDialog> createState() => _FiguresDialogState();
}

class _FiguresDialogState extends State<_FiguresDialog> {
  late final _kcal = _field(widget.item.kcal);
  late final _protein = _field(widget.item.proteinGrams);
  late final _carb = _field(widget.item.carbGrams);
  late final _fat = _field(widget.item.fatGrams);

  static TextEditingController _field(int? value) =>
      TextEditingController(text: value == null ? '' : '$value');

  static int? _read(TextEditingController field) =>
      double.tryParse(field.text.trim())?.round();

  @override
  void dispose() {
    for (final field in [_kcal, _protein, _carb, _fat]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AppDialog(
      title: item.name,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumberFieldRow(
            label: MacroLabel.energy,
            unit: 'kcal',
            controller: _kcal,
          ),
          NumberFieldRow(
            label: MacroLabel.protein,
            unit: 'g',
            controller: _protein,
          ),
          NumberFieldRow(label: MacroLabel.carb, unit: 'g', controller: _carb),
          NumberFieldRow(label: MacroLabel.fat, unit: 'g', controller: _fat),
        ],
      ),
      actions: [
        DialogAction(
          label: '儲存',
          tone: DialogTone.primary,
          onTap: () => Navigator.of(context).pop(
            DraftItem(
              name: item.name,
              amount: item.amount,
              kcal: _read(_kcal),
              proteinGrams: _read(_protein),
              carbGrams: _read(_carb),
              fatGrams: _read(_fat),
              fibreGrams: item.fibreGrams,
              nutrients: item.nutrients,
              isDrink: item.isDrink,
            ),
          ),
        ),
        DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}
