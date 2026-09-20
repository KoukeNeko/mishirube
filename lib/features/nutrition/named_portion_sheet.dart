import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// Asks for a named portion — `一匙 = 15 g` — and resolves to it.
///
/// The name is whatever the user calls it and the amount is whatever
/// they say it is. Nothing here consults a table of household measures,
/// because there is no table that is right for every food.
Future<NamedPortion?> showNamedPortionSheet(
  BuildContext context, {
  required ServingUnit unit,
}) {
  return showModalBottomSheet<NamedPortion>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _NamedPortionSheet(unit: unit),
  );
}

class _NamedPortionSheet extends StatefulWidget {
  const _NamedPortionSheet({required this.unit});

  final ServingUnit unit;

  @override
  State<_NamedPortionSheet> createState() => _NamedPortionSheetState();
}

class _NamedPortionSheetState extends State<_NamedPortionSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  late ServingUnit _unit = widget.unit;

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  bool get _canSave => _name.text.trim().isNotEmpty && _value > 0;

  @override
  void initState() {
    super.initState();
    for (final field in [_name, _amount]) {
      field.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('新增常用份量', style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.lg),
          Text('怎麼稱呼', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(controller: _name, hint: '例如：一匙', autofocus: true),
          const SizedBox(height: AppSpacing.md),
          Text('它是多少', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: AppTextField(
                  controller: _amount,
                  hint: '15',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ChipWrap(
                  options: widget.unit.comparable.toList(),
                  labelOf: (unit) => unit.label,
                  isSelected: (unit) => unit == _unit,
                  onTap: (unit) => setState(() => _unit = unit),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: '加入',
            onPressed: _canSave
                ? () => Navigator.of(context).pop(
                    NamedPortion(
                      name: _name.text.trim(),
                      amount: _value,
                      unit: _unit,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
