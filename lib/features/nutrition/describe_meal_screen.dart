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
import 'food_edit_screen.dart';
import 'nutrition_view_model.dart';
import '../../l10n/l10n.dart';

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
  Future<void> _editItem(int index) async {
    final edited = await pushPage<DraftItem>(
      context,
      FoodEditScreen(draftItem: _items[index]),
    );
    if (edited == null || !mounted) return;
    setState(() => _items = [..._items]..[index] = edited);
  }

  void _remove(int index) {
    final removed = _items[index];
    setState(() => _items = [..._items]..removeAt(index));
    ToastScope.read(context).showUndo(
      context.l10n.removedNamed(name: removed.name),
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
    String? name;
    if (_items.length > 1 && widget.draft == null) {
      final choice = await showAppDialog<(bool, String)>(
        context,
        _MealChoiceDialog(
          count: _items.length,
          name: _draft!.name ?? '',
          itemsName: joinList(context.l10n, _items.map((item) => item.name)),
        ),
      );
      if (choice == null || !mounted) return;
      (asOneMeal, name) = choice;
    }
    final logged = _nutrition.logDraft(
      _draft!,
      _items,
      mealType: widget.mealType,
      asOneMeal: asOneMeal,
      name: name,
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
        title: widget._isPhoto
            ? context.l10n.photoEstimate
            : context.l10n.describeMealTitle,
        subtitle: currentAiLabel(context.l10n, store),
      ),
      footer: draft == null
          ? DraftButton(
              isDrafting: _isDrafting,
              label: widget.photoPath != null
                  ? context.l10n.retry
                  : context.l10n.aiDraftGenerate,
              onPressed:
                  (widget.photoPath == null && _text.text.trim().isEmpty) ||
                      store.aiProvider == null
                  ? null
                  : _generate,
            )
          : PrimaryButton(
              label: context.l10n.logItemsCount(count: _items.length),
              onPressed: _items.isEmpty ? null : _log,
            ),
      children: [
        if (store.aiProvider == null && !widget._isPhoto) ...[
          Gutter(
            child: InfoBanner(
              icon: Icons.auto_awesome_outlined,
              message: context.l10n.chooseAiFirst,
            ),
          ),
          Gutter(
            child: LinkText(
              label: context.l10n.openAiSettings(me: context.l10n.tabMe),
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
                semanticLabel: context.l10n.foodPhoto,
              ),
            ),
          ),
        if (!widget._isPhoto)
          Gutter(
            child: DescribeField(
              controller: _text,
              hint: context.l10n.describeMealHint,
            ),
          ),
        if (_failure case final failure?)
          Gutter(child: AiFailureBanner(failure: failure)),
        if (draft != null) ...[
          if (draft.warnings.isNotEmpty)
            Gutter(
              child: InfoBanner(
                tone: CardTone.warning,
                message: [
                  for (final warning in draft.warnings)
                    warning.text(context.l10n),
                ].join('\n'),
              ),
            ),
          Gutter(child: SectionLabel(context.l10n.draftSection)),
          for (final (index, item) in _items.indexed)
            Gutter(
              child: SwipeAction(
                key: ValueKey('${item.name}$index'),
                label: context.l10n.removeAction,
                semanticLabel: context.l10n.removeNamed(name: item.name),
                onAction: () => _remove(index),
                child: NavCard(
                  title: item.name,
                  subtitle:
                      '${item.amount} · '
                      '${formatKcalOrDash(item.kcal)} kcal',
                  detail: _macrosOf(context.l10n, item),
                  onTap: () => _editItem(index),
                ),
              ),
            ),
          Gutter(
            child: DraftAttribution(
              label: aiLabel(context.l10n, draft.provider, draft.model),
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
String _macrosOf(AppLocalizations l10n, DraftItem item) {
  String grams(int? value) => value == null ? '—' : '$value g';
  final more = [
    if (item.fibreGrams case final fibre?) '${l10n.macroFibre} $fibre g',
    for (final MapEntry(key: nutrient, value: amount) in item.nutrients.entries)
      '${nutrient.labelIn(l10n)} ${nutrient.format(amount)}',
  ];
  return [
    [
      '${l10n.macroProtein} ${grams(item.proteinGrams)}',
      '${l10n.macroCarb} ${grams(item.carbGrams)}',
      '${l10n.macroFat} ${grams(item.fatGrams)}',
    ].join(' · '),
    if (more.isNotEmpty) more.join(' · '),
  ].join('\n');
}

/// One meal or several, with the name the meal would go by: the AI's
/// suggestion to keep or change, and blank for its items' names.
class _MealChoiceDialog extends StatefulWidget {
  const _MealChoiceDialog({
    required this.count,
    required this.name,
    required this.itemsName,
  });

  final int count;
  final String name;

  /// What a meal without a name of its own is called.
  final String itemsName;

  @override
  State<_MealChoiceDialog> createState() => _MealChoiceDialogState();
}

class _MealChoiceDialogState extends State<_MealChoiceDialog> {
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.itemsCountShort(count: widget.count),
    content: AppTextField(controller: _name, hint: widget.itemsName),
    actions: [
      DialogAction(
        label: context.l10n.mergeIntoMeal,
        onTap: () => Navigator.of(context).pop((true, _name.text)),
      ),
      DialogAction(
        label: context.l10n.logEachItem,
        tone: DialogTone.primary,
        onTap: () => Navigator.of(context).pop((false, _name.text)),
      ),
      DialogAction(
        label: context.l10n.commonCancel,
        onTap: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
