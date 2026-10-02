import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';

/// shared_preferences key holding the JSON list of saved itineraries.
const String kItinerariesKey = 'gotrvl_itineraries';

/// "₱5,000" style formatting for budget values.
String formatPhp(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '₱$buf';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// "Sep 30, 2026" style date formatting.
String formatTripDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class TripItem {
  final String time;
  final String title;
  final String detail;

  const TripItem(
      {required this.time, required this.title, required this.detail});

  Map<String, dynamic> toJson() =>
      {'time': time, 'title': title, 'detail': detail};

  factory TripItem.fromJson(Map<String, dynamic> j) => TripItem(
        time: j['time'] ?? '',
        title: j['title'] ?? '',
        detail: j['detail'] ?? '',
      );
}

class TripDay {
  final int dayIndex;
  final String title;
  final List<TripItem> items;

  const TripDay(
      {required this.dayIndex, required this.title, required this.items});

  Map<String, dynamic> toJson() => {
        'dayIndex': dayIndex,
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory TripDay.fromJson(Map<String, dynamic> j) => TripDay(
        dayIndex: (j['dayIndex'] as num?)?.toInt() ?? 0,
        title: j['title'] ?? '',
        items: ((j['items'] as List?) ?? [])
            .map((e) => TripItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TripItinerary {
  final String id;
  final String destinationId;
  final String destinationName;
  final DateTime start;
  final DateTime end;
  final double budgetMin;
  final double budgetMax;
  final List<String> styles;
  final List<TripDay> days;

  const TripItinerary({
    required this.id,
    required this.destinationId,
    required this.destinationName,
    required this.start,
    required this.end,
    required this.budgetMin,
    required this.budgetMax,
    required this.styles,
    required this.days,
  });

  int get dayCount => days.length;

  String get dateLabel => '${formatTripDate(start)} - ${formatTripDate(end)}';

  String get budgetLabel => '${formatPhp(budgetMin)} - ${formatPhp(budgetMax)}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'destinationId': destinationId,
        'destinationName': destinationName,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'styles': styles,
        'days': days.map((e) => e.toJson()).toList(),
      };

  factory TripItinerary.fromJson(Map<String, dynamic> j) => TripItinerary(
        id: j['id'] ?? '',
        destinationId: j['destinationId'] ?? '',
        destinationName: j['destinationName'] ?? '',
        start: DateTime.tryParse(j['start'] ?? '') ?? DateTime.now(),
        end: DateTime.tryParse(j['end'] ?? '') ?? DateTime.now(),
        budgetMin: (j['budgetMin'] as num?)?.toDouble() ?? 0,
        budgetMax: (j['budgetMax'] as num?)?.toDouble() ?? 0,
        styles: ((j['styles'] as List?) ?? []).cast<String>(),
        days: ((j['days'] as List?) ?? [])
            .map((e) => TripDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// Generation: honest day-by-day plan built from the destination's own places.
// ---------------------------------------------------------------------------

/// Builds a day-by-day itinerary from the destination's places:
/// 10:00 AM and 3:00 PM explore slots (things_to_do / where_to_go,
/// round-robin), 1:00 PM lunch and 7:00 PM dinner (where_to_eat),
/// 8:00 AM arrival on day one and a departure slot on the last day.
/// Day count is the selected range length, clamped to 1..7.
TripItinerary buildItinerary({
  required String id,
  required Destination destination,
  required DateTime start,
  required DateTime end,
  required double budgetMin,
  required double budgetMax,
  required List<String> styles,
}) {
  final rawDays = end.difference(start).inDays + 1;
  final dayCount = rawDays.clamp(1, 7);

  final explore = [
    ...destination.placesIn('things_to_do'),
    ...destination.placesIn('where_to_go'),
  ];
  final food = destination.placesIn('where_to_eat');
  var ei = 0;
  var fi = 0;
  Place? nextExplore() =>
      explore.isEmpty ? null : explore[(ei++) % explore.length];
  Place? nextFood() => food.isEmpty ? null : food[(fi++) % food.length];

  String detailFor(Place p) {
    var d = p.description.trim();
    if (d.length > 110) d = '${d.substring(0, 107)}...';
    final area = p.area.trim();
    if (area.isEmpty) return d;
    if (d.isEmpty) return area;
    return '$d · $area';
  }

  final days = <TripDay>[];
  for (var i = 0; i < dayCount; i++) {
    final isFirst = i == 0;
    final isLast = i == dayCount - 1;
    final items = <TripItem>[];

    if (isFirst) {
      items.add(TripItem(
        time: '8:00 AM',
        title: 'Arrival',
        detail: 'Arrive in ${destination.name} and settle in.',
      ));
    }
    final morning = nextExplore();
    if (morning != null) {
      items.add(TripItem(
          time: '10:00 AM', title: morning.name, detail: detailFor(morning)));
    }
    final lunch = nextFood();
    if (lunch != null) {
      items.add(TripItem(
          time: '1:00 PM',
          title: 'Lunch at ${lunch.name}',
          detail: detailFor(lunch)));
    }
    final afternoon = nextExplore();
    if (afternoon != null) {
      items.add(TripItem(
          time: '3:00 PM',
          title: afternoon.name,
          detail: detailFor(afternoon)));
    }
    if (isLast) {
      items.add(TripItem(
        time: '5:00 PM',
        title: 'Departure',
        detail: 'Check out and head home from ${destination.name}.',
      ));
    }
    final dinner = nextFood();
    if (dinner != null) {
      items.add(TripItem(
          time: '7:00 PM',
          title: 'Dinner at ${dinner.name}',
          detail: detailFor(dinner)));
    }

    final title = dayCount == 1
        ? 'Arrival and Departure'
        : isFirst
            ? 'Arrival Day'
            : isLast
                ? 'Departure Day'
                : 'Explore Day ${i + 1}';
    days.add(TripDay(dayIndex: i + 1, title: title, items: items));
  }

  return TripItinerary(
    id: id,
    destinationId: destination.id,
    destinationName: destination.name,
    start: start,
    end: end,
    budgetMin: budgetMin,
    budgetMax: budgetMax,
    styles: styles,
    days: days,
  );
}

/// Loads all saved itineraries from shared_preferences.
Future<List<TripItinerary>> loadSavedItineraries() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kItinerariesKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = json.decode(raw) as List;
    return list
        .map((e) => TripItinerary.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Persists an itinerary, replacing any previous save with the same id.
Future<void> saveItinerary(TripItinerary itinerary) async {
  final prefs = await SharedPreferences.getInstance();
  final all = await loadSavedItineraries();
  all.removeWhere((t) => t.id == itinerary.id);
  all.insert(0, itinerary);
  await prefs.setString(
      kItinerariesKey, json.encode(all.map((t) => t.toJson()).toList()));
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Shows a generated trip: Itinerary and Details tabs, plus save.
class ItineraryScreen extends StatefulWidget {
  final TripItinerary itinerary;

  const ItineraryScreen({super.key, required this.itinerary});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  Destination? _destination;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    DataService().load().then((_) {
      if (!mounted) return;
      setState(() {
        _destination = DataService()
            .destinations
            .where((d) => d.id == widget.itinerary.destinationId)
            .cast<Destination?>()
            .firstWhere((d) => d != null, orElse: () => null);
      });
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await saveItinerary(widget.itinerary);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip saved to My Trips')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.itinerary;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: BohoColors.cream,
        appBar: AppBar(
          backgroundColor: BohoColors.cream,
          title: Text('Your Trip to ${t.destinationName}',
              style: BohoFonts.script(26, color: BohoColors.espresso)),
          bottom: const TabBar(
            labelColor: BohoColors.forest,
            unselectedLabelColor: BohoColors.espresso,
            indicatorColor: BohoColors.forest,
            tabs: [Tab(text: 'Itinerary'), Tab(text: 'Details')],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                '${t.dateLabel} · ${t.dayCount} Days · ${t.budgetLabel}',
                style: BohoFonts.body(14,
                    color: BohoColors.espresso, weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _itineraryTab(t),
                  _detailsTab(t),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(
                  label: _saving ? 'Saving...' : 'Save Itinerary',
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itineraryTab(TripItinerary t) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: t.days.length,
      itemBuilder: (context, i) => _dayCard(t.days[i]),
    );
  }

  Widget _dayCard(TripDay day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: BohoColors.forest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('Day ${day.dayIndex}',
                    style: BohoFonts.body(13,
                        color: Colors.white, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(day.title,
                    style: BohoFonts.heading(16, color: BohoColors.espresso)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in day.items) _timelineRow(item),
        ],
      ),
    );
  }

  Widget _timelineRow(TripItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(item.time,
                style: BohoFonts.body(13,
                    color: BohoColors.forest, weight: FontWeight.w800)),
          ),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: const BoxDecoration(
              color: BohoColors.terracotta,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: BohoFonts.body(14,
                        color: BohoColors.espresso, weight: FontWeight.w700)),
                if (item.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.detail,
                      style: BohoFonts.body(13,
                          color: BohoColors.espresso.withValues(alpha: 0.7))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsTab(TripItinerary t) {
    final d = _destination;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _detailCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Budget',
          child: Text(t.budgetLabel,
              style: BohoFonts.heading(20, color: BohoColors.terracotta)),
        ),
        _detailCard(
          icon: Icons.style_rounded,
          title: 'Travel style',
          child: t.styles.isEmpty
              ? Text('Anything goes',
                  style: BohoFonts.body(14, color: BohoColors.espresso))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in t.styles)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: BohoColors.forest.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(s,
                            style: BohoFonts.body(13,
                                color: BohoColors.forest,
                                weight: FontWeight.w700)),
                      ),
                  ],
                ),
        ),
        if (d != null && d.bestTime.isNotEmpty)
          _detailCard(
            icon: Icons.wb_sunny_rounded,
            title: 'Best time to visit',
            child: Text(d.bestTime,
                style: BohoFonts.body(14, color: BohoColors.espresso)),
          ),
        if (d != null && d.howToGetThere.isNotEmpty)
          _detailCard(
            icon: Icons.directions_rounded,
            title: 'How to get there',
            child: Text(d.howToGetThere,
                style: BohoFonts.body(14, color: BohoColors.espresso)),
          ),
      ],
    );
  }

  Widget _detailCard(
      {required IconData icon, required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: BohoColors.forest),
              const SizedBox(width: 8),
              Text(title,
                  style: BohoFonts.heading(16, color: BohoColors.espresso)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
