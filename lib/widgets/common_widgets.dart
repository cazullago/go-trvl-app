import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';

/// Shared building blocks for the GoTRVL PH redesign, matching the
/// approved mockup.

/// Rounded white search field with a dusty-blue magnifier.
class SearchBarField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final bool readOnly;

  const SearchBarField({
    super.key,
    required this.hint,
    this.onChanged,
    this.controller,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: BohoColors.espresso.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        readOnly: readOnly,
        style: BohoFonts.body(14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: BohoColors.dustyBlue,
          ),
        ),
      ),
    );
  }
}

/// Bold Poppins section title with an optional trailing action
/// (e.g. "See all").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: BohoFonts.heading(17)),
        ),
        if (actionLabel != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: BohoFonts.body(
                      13,
                      color: BohoColors.dustyBlue,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: BohoColors.dustyBlue,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Primary call-to-action: forest green, rounded 16, white Poppins 700.
/// Styling comes from the theme; this just fixes the height and adds an
/// optional icon.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? ElevatedButton(
            onPressed: onPressed,
            child: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label),
          );
    return SizedBox(height: 52, child: button);
  }
}

/// Pastel circle tile with an icon and a small label, per the mockup
/// category row (Near Me, Explore PH, Travel Alerts, Popular, ...).
class CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const CategoryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: BohoFonts.body(11, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Centered placeholder for empty lists: soft icon disc plus message.
class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.text,
    this.icon = Icons.beach_access,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: BohoColors.dustyBlue.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: BohoColors.dustyBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: BohoFonts.body(
                14,
                color: BohoColors.espresso.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
