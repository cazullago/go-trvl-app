import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/quest_service.dart';
import '../services/synthetic_quests.dart';
import '../theme/boho_theme.dart';
import 'quest_opener.dart';

/// A province's "Where to Go": its cities and municipalities, each a
/// completable 500-pt quest stop with details and memories.
class CityListScreen extends StatelessWidget {
  final Province province;

  const CityListScreen({super.key, required this.province});

  @override
  Widget build(BuildContext context) {
    final stops = SyntheticQuests.citiesOf(province);
    final allPlaces = [...QuestService().all, ...stops];
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: BohoColors.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('🏝️ Where to Go',
            style: BohoFonts.display(24, color: BohoColors.espresso)),
      ),
      body: Consumer<AuthService>(
        builder: (context, auth, _) {
          final doneIds = auth.user?.donePlaceIds ?? const <String>{};
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: stops.length,
            itemBuilder: (_, i) {
              final q = stops[i];
              final done = doneIds.contains(q.id);
              final city = province.cities[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () =>
                      QuestOpener.open(context, q, allPlaces: allPlaces),
                  child: Container(
                    decoration: BohoDecor.card(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(q.name,
                                  style: BohoFonts.body(18,
                                      weight: FontWeight.w800)),
                            ),
                            const Text('🏝️',
                                style: TextStyle(fontSize: 24)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(q.blurb,
                            style: BohoFonts.body(13,
                                color: BohoColors.espresso
                                    .withValues(alpha: 0.65)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                            city.isCity ? 'City' : 'Municipality',
                            style: BohoFonts.body(12,
                                color: BohoColors.espresso
                                    .withValues(alpha: 0.5))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('${q.points} pts',
                                style: BohoFonts.body(14,
                                    color: BohoColors.terracotta,
                                    weight: FontWeight.w800)),
                            if (done) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded,
                                  color: BohoColors.leaf, size: 16),
                            ],
                            const Spacer(),
                            Text('View Details →',
                                style: BohoFonts.body(13,
                                    color: BohoColors.dustyBlue,
                                    weight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
