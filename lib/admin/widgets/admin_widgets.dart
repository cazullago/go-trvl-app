// GoTRVL PH admin dashboard: shared widgets.
//
// SECURITY MODEL: admin role is a Firebase custom claim only. Firestore
// rules enforce it server-side. The app never hardcodes credentials and
// never bypasses auth. All writes go through the signed-in admin's
// authenticated session.

import 'package:flutter/material.dart';
import '../../theme/boho_theme.dart';

/// Small KPI card: label, value, icon, accent color.
class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BohoDecor.card(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: BohoFonts.heading(24),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: BohoFonts.capsLabel(11, color: BohoColors.sandMuted),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading used across admin screens.
class AdminSectionTitle extends StatelessWidget {
  final String text;

  const AdminSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const HibiscusStamp(size: 30, opacity: 0.7),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: BohoFonts.heading(20)),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown when a list or stat group has nothing to show yet.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48, color: BohoColors.sandMuted.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              message,
              style: BohoFonts.body(15, color: BohoColors.sandMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation dialog for destructive or privileged admin actions.
/// Returns true when the admin confirms, false otherwise.
Future<bool> adminConfirmDialog(
  BuildContext context,
  String title,
  String message,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BohoColors.creamSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: BohoColors.sandDark),
      ),
      title: Text(title, style: BohoFonts.heading(18)),
      content: Text(message, style: BohoFonts.body(14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel',
              style: BohoFonts.body(14,
                  color: BohoColors.sandMuted, weight: FontWeight.w700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: BohoColors.terracotta,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child:
              Text('Confirm', style: BohoFonts.body(14, color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}
