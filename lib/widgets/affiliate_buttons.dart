import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/monetization_models.dart';
import '../theme/boho_theme.dart';

/// Row of affiliate/booking partner buttons for a place or destination.
///
/// Auto-hides (renders nothing) when [links] is empty, e.g. when
/// affiliates are disabled or unconfigured, so the UI never shows dead
/// buttons. Tapping a button always opens the partner's EXTERNAL site in
/// the system browser; no booking money ever passes through the app.
class AffiliateButtons extends StatelessWidget {
  final List<AffiliateLink> links;

  const AffiliateButtons({super.key, required this.links});

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    final shown = links.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < shown.length; i++)
              i == 0
                  ? ElevatedButton(
                      onPressed: () => _open(shown[i].url),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BohoColors.forest,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        textStyle: BohoFonts.body(14, weight: FontWeight.w700),
                      ),
                      child: Text(shown[i].label),
                    )
                  : OutlinedButton(
                      onPressed: () => _open(shown[i].url),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BohoColors.forest,
                        side: const BorderSide(
                            color: BohoColors.forest, width: 1.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        textStyle: BohoFonts.body(14, weight: FontWeight.w700),
                      ),
                      child: Text(shown[i].label),
                    ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Affiliate link: we may earn a commission',
          style: BohoFonts.body(10, color: BohoColors.dustyBlue),
        ),
      ],
    );
  }
}
