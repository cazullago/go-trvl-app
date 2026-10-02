import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/monetization_models.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';

/// Go TRVL Premium: not launched yet. This screen lists the planned
/// premium features and lets travelers opt in for a launch notification.
/// Core travel features stay free forever.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const _notifyKey = 'premium_notify_me';
  bool _notified = false;
  bool _loading = true;

  static const _icons = [
    Icons.map_rounded,
    Icons.download_rounded,
    Icons.local_offer_rounded,
    Icons.bookmark_rounded,
    Icons.auto_stories_rounded,
    Icons.route_rounded,
  ];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _notified = prefs.getBool(_notifyKey) ?? false;
          _loading = false;
        });
      }
    });
  }

  Future<void> _notifyMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyKey, true);
    if (!mounted) return;
    setState(() => _notified = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("We'll let you know!")));
  }

  @override
  Widget build(BuildContext context) {
    final features = PremiumFeature.values;
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Premium',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Go TRVL Premium',
                    style: BohoFonts.script(32, color: BohoColors.espresso)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: BohoColors.terracotta,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('Coming Soon',
                    style: BohoFonts.body(12,
                        color: Colors.white, weight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Every core travel feature stays free forever.',
              style: BohoFonts.body(15,
                  color: BohoColors.espresso.withValues(alpha: 0.75),
                  weight: FontWeight.w600)),
          const SizedBox(height: 20),
          for (var i = 0; i < features.length; i++)
            _featureCard(features[i], _icons[i % _icons.length]),
          const SizedBox(height: 24),
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: BohoColors.forest))
          else if (_notified)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BohoColors.forest.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: BohoColors.forest),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        "You're on the list. We'll tell you when Premium launches.",
                        style: BohoFonts.body(14,
                            color: BohoColors.espresso,
                            weight: FontWeight.w600)),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Notify me',
                icon: Icons.notifications_rounded,
                onPressed: _notifyMe,
              ),
            ),
        ],
      ),
    );
  }

  Widget _featureCard(PremiumFeature feature, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: BohoColors.dustyBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: BohoColors.dustyBlue, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.label,
                    style: BohoFonts.body(15,
                        color: BohoColors.espresso, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(feature.description,
                    style: BohoFonts.body(14,
                        color: BohoColors.espresso.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
