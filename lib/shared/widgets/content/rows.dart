import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'cards.dart';

/// The app's list row: an optional leading marker, a title, up to two
/// lines under it, and a trailing value or control. A row that opens
/// something ends in a chevron; one that does not, or whose tap does
/// something else (select, toggle), does not.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.title,
    this.titleTrailing,
    this.subtitle,
    this.detail,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron,
  });

  final String title;

  /// A small mark after the title, such as a favourite's star.
  final Widget? titleTrailing;
  final String? subtitle;

  /// A quieter third line: when it was last done, where it comes from.
  final String? detail;
  final Widget? leading;

  /// A value or control at the end of the row.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Whether the row ends in a chevron; by default when it opens
  /// something and has nothing else at its end.
  final bool? showChevron;

  bool get _showsChevron => showChevron ?? (onTap != null && trailing == null);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: AppTextStyles.itemTitle),
                      ),
                      if (titleTrailing != null) ...[
                        const SizedBox(width: AppSpacing.xxs),
                        titleTrailing!,
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!, style: AppTextStyles.caption),
                  ],
                  if (detail != null)
                    Text(
                      detail!,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.xs),
              trailing!,
            ],
            if (_showsChevron)
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Row with a coloured bar on the left that marks its record category.
class AccentRow extends StatelessWidget {
  const AccentRow({
    super.key,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  final Color color;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return NavCard(
      leading: AccentBar(color: color, height: subtitle == null ? 20 : 34),
      title: title,
      subtitle: subtitle,
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
      onTap: onTap,
      showChevron: showChevron,
    );
  }
}

class AccentBar extends StatelessWidget {
  const AccentBar({super.key, required this.color, this.height = 20});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// A setting that is on or off. The switch is the answer, so the whole
/// row flips it and there is no chevron.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // One element for a screen reader: the title and the switch's state.
    return MergeSemantics(
      child: NavRow(
        title: title,
        subtitle: subtitle,
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.training,
        ),
        onTap: () => onChanged(!value),
        showChevron: false,
      ),
    );
  }
}

/// Square checkbox row used by permission and module lists.
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.title,
    required this.isChecked,
    required this.onChanged,
    this.badge,
  });

  final String title;
  final bool isChecked;
  final ValueChanged<bool> onChanged;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: isChecked,
      child: NavRow(
        title: title,
        titleTrailing: badge,
        trailing: CheckSquare(isChecked: isChecked),
        onTap: () => onChanged(!isChecked),
      ),
    );
  }
}

class CheckSquare extends StatelessWidget {
  const CheckSquare({
    super.key,
    required this.isChecked,
    this.size = 22,
    this.checkedColor = AppColors.training,
    this.uncheckedColor = Colors.white,
  });

  final bool isChecked;
  final double size;
  final Color checkedColor;
  final Color uncheckedColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isChecked ? checkedColor : uncheckedColor,
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: isChecked
          ? Icon(Icons.check, size: size * 0.8, color: AppColors.onTraining)
          : null,
    );
  }
}

/// Round radio button row used for scope choices.
class RadioRow extends StatelessWidget {
  const RadioRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      child: NavCard(
        tone: isSelected ? CardTone.training : CardTone.neutral,
        leading: RadioDot(isSelected: isSelected),
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        showChevron: false,
      ),
    );
  }
}

class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.isSelected});

  static const _size = 24.0;

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.training : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.training : AppColors.textTertiary,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: AppColors.onTraining)
          : null,
    );
  }
}

/// Label on the left, value on the right (exercise specs, key facts).
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          // Either side wraps rather than push the other past the edge.
          Flexible(child: Text(label, style: AppTextStyles.caption)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A [NavRow] on its own card: the item of a list whose items stand
/// apart, such as foods, exercises and templates.
class NavCard extends StatelessWidget {
  const NavCard({
    super.key,
    required this.title,
    this.titleTrailing,
    this.subtitle,
    this.detail,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron,
    this.tone = CardTone.neutral,
  });

  final String title;
  final Widget? titleTrailing;
  final String? subtitle;
  final String? detail;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? showChevron;

  /// [CardTone.training] marks a chosen item.
  final CardTone tone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: tone,
      padding: EdgeInsets.zero,
      radius: AppRadius.small + 4,
      child: NavRow(
        title: title,
        titleTrailing: titleTrailing,
        subtitle: subtitle,
        detail: detail,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
        showChevron: showChevron,
      ),
    );
  }
}
