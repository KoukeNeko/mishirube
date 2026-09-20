import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// Creating or correcting one of the user's own foods.
///
/// Every number here is typed by hand, so the screen never dresses them
/// up as a lookup: what goes in is what comes back out.
class FoodEditScreen extends StatefulWidget {
  const FoodEditScreen({super.key, this.editing, this.initialName = ''});

  /// The food being corrected; null when adding a new one.
  final FoodItem? editing;

  final String initialName;

  @override
  State<FoodEditScreen> createState() => _FoodEditScreenState();
}

class _FoodEditScreenState extends State<FoodEditScreen> {
  late final _name = TextEditingController(
    text: widget.editing?.name ?? widget.initialName,
  );
  late final _brand = TextEditingController(text: widget.editing?.brand ?? '');
  late final _serving = TextEditingController(
    text: widget.editing?.servingLabel ?? '',
  );
  late final _kcal = _number(widget.editing?.kcal);
  late final _protein = _number(widget.editing?.proteinGrams);
  late final _carb = _number(widget.editing?.carbGrams);
  late final _fat = _number(widget.editing?.fatGrams);
  late final _fibre = _number(widget.editing?.fibreGrams);

  static TextEditingController _number(int? value) =>
      TextEditingController(text: value == null ? '' : '$value');

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _serving]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _brand,
      _serving,
      _kcal,
      _protein,
      _carb,
      _fat,
      _fibre,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _serving.text.trim().isNotEmpty;

  void _save() {
    final store = AppStoreScope.read(context);
    final food = FoodItem(
      id: widget.editing?.id ?? store.newFoodId(),
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      servingLabel: _serving.text.trim(),
      kcal: _valueOf(_kcal),
      proteinGrams: _valueOf(_protein),
      carbGrams: _valueOf(_carb),
      fatGrams: _valueOf(_fat),
      fibreGrams: _valueOf(_fibre),
    );
    store.saveFood(food);
    Navigator.of(context).pop(food);
  }

  /// An empty field is zero: the user left it out, which is not the same
  /// as the app guessing a number for them.
  static int _valueOf(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final isNew = widget.editing == null;
    return DetailPage(
      appBar: PageAppBar(
        title: isNew ? '新增食物' : '編輯食物',
        subtitle: '只存在這台裝置',
        leading: AppBarLeading.none,
        onClose: () => Navigator.of(context).pop(),
      ),
      footer: PrimaryButton(
        label: isNew ? '儲存' : '儲存變更',
        onPressed: _canSave ? _save : null,
      ),
      children: [
        Gutter(child: const SectionLabel('名稱')),
        Gutter(child: AppTextField(controller: _name, hint: '例如：雞胸肉')),
        Gutter(child: const SectionLabel('品牌（沒有就留空）')),
        Gutter(child: AppTextField(controller: _brand, hint: '例如：大成')),
        Gutter(child: const SectionLabel('一份是多少')),
        Gutter(
          child: AppTextField(controller: _serving, hint: '例如：一片（約 100 g）'),
        ),
        Gutter(
          child: const Text(
            '這是一段文字，不是數量。App 不會替你換算單位，所以怎麼寫就怎麼讀。',
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(child: const SectionLabel('每份營養')),
        Gutter(
          child: _NumberField(label: '熱量 (kcal)', controller: _kcal),
        ),
        Gutter(child: _NumberField(label: '蛋白質 (g)', controller: _protein)),
        Gutter(child: _NumberField(label: '碳水 (g)', controller: _carb)),
        Gutter(child: _NumberField(label: '脂肪 (g)', controller: _fat)),
        Gutter(child: _NumberField(label: '膳食纖維 (g)', controller: _fibre)),
        Gutter(
          child: const Text(
            '沒填的欄位會記成 0。這代表你沒有填，而不是這份食物真的是 0。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.body)),
        SizedBox(
          width: 120,
          child: AppTextField(
            controller: controller,
            hint: '0',
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }
}
