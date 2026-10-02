import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/ph_stickers.dart';

/// First-run tutorial: 4 short swipeable cards (PageView + dots +
/// Skip/Next). "Start exploring" marks onboardingDone=true and drops the
/// traveler into the HomeShell. Pushed once by HomeShell for users who
/// signed up but never finished it.
class OnboardingTutorial extends StatefulWidget {
  const OnboardingTutorial({super.key});

  @override
  State<OnboardingTutorial> createState() => _OnboardingTutorialState();
}

class _OnboardingTutorialState extends State<OnboardingTutorial> {
  final _pages = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final auth = context.read<AuthService>();
    final uid = auth.user?.uid ?? '';
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'onboardingDone': true});
        await auth.refreshUser();
      } catch (_) {
        // Best-effort: still let them into the app.
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == 3;
    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip',
                    style: BohoFonts.body(15,
                        color: BohoColors.cocoaSoft, weight: FontWeight.w700)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [
                  _TutorialPage(
                    sticker: _StickerKind.coconut,
                    title: 'Five tabs, zero confusion',
                    body:
                        'Map to explore the Philippines. Feed for stories and posts. The big + to share. Matching to find a travel buddy. Profile as your travel scrapbook.',
                    bullets: [
                      ('\u{1F5FA}\uFE0F', 'Map'),
                      ('\u{1F4F8}', 'Feed'),
                      ('➕', 'Create'),
                      ('\u{2764}\uFE0F', 'Matching'),
                      ('\u{1F9D1}', 'Profile'),
                    ],
                  ),
                  _TutorialPage(
                    sticker: _StickerKind.sun,
                    title: 'Travel is a game',
                    body:
                        'Mark places done to earn points, climb traveler levels, collect passport stamps, and finish quests.',
                    bullets: [
                      ('\u{1F331}', 'New Traveler'),
                      ('\u{1F9ED}', 'Explorer'),
                      ('\u{26F0}\uFE0F', 'Adventurer'),
                      ('\u{1F3DD}\uFE0F', 'Island Hopper'),
                      ('\u{1F451}', 'Legendary'),
                    ],
                  ),
                  _TutorialPage(
                    sticker: _StickerKind.wave,
                    title: 'Unlock the map',
                    body:
                        'Say you are in Manila and curious about Boracay. Go Premium and the whole map opens. Walk near a place and it opens. Places you have visited stay open. Otherwise, finish tasks or unlock a place.',
                    bullets: [
                      ('⭐', 'Premium: whole map'),
                      ('\u{1F4CD}', 'Nearby: opens'),
                      ('✅', 'Visited: stays open'),
                      ('\u{1F3AF}', 'Else: tasks or unlock'),
                    ],
                  ),
                  _TutorialPage(
                    sticker: _StickerKind.parol,
                    title: 'Permissions, only when needed',
                    body:
                        'We will ask for camera and photos when you share, location for nearby unlocks, and notifications for matches. Only when needed, never all at once.',
                    bullets: [
                      ('\u{1F4F7}', 'Camera and photos'),
                      ('\u{1F4CD}', 'Location'),
                      ('\u{1F514}', 'Notifications'),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    width: _index == i ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _index == i
                          ? BohoColors.forest
                          : BohoColors.tan.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: BohoColors.forest),
                  onPressed: _finishing
                      ? null
                      : () {
                          if (last) {
                            _finish();
                          } else {
                            _pages.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                  child: _finishing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(last ? 'Start exploring' : 'Next'),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

enum _StickerKind { coconut, sun, wave, parol }

class _TutorialPage extends StatelessWidget {
  final _StickerKind sticker;
  final String title;
  final String body;
  final List<(String, String)> bullets;

  const _TutorialPage({
    required this.sticker,
    required this.title,
    required this.body,
    required this.bullets,
  });

  Widget _sticker() {
    switch (sticker) {
      case _StickerKind.coconut:
        return PhStickers.coconutTree(size: 110);
      case _StickerKind.sun:
        return PhStickers.sun(size: 96);
      case _StickerKind.wave:
        return PhStickers.wave(size: 104);
      case _StickerKind.parol:
        return PhStickers.parol(size: 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _sticker(),
          const SizedBox(height: 28),
          Text(title,
              style: BohoFonts.script(34, color: BohoColors.espresso),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Text(body,
              style: BohoFonts.body(15,
                  color: BohoColors.espresso.withValues(alpha: 0.8)),
              textAlign: TextAlign.center),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final (emoji, label) in bullets)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BohoColors.tan, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(label,
                          style: BohoFonts.body(13,
                              color: BohoColors.espresso,
                              weight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
