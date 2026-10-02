import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';
import 'itinerary_screen.dart';

const _styleOptions = [
  'Beach',
  'Nature',
  'Food',
  'Culture',
  'City',
  'Romantic',
  'Adventure',
];

/// Trip planner: destination, dates, budget and travel style form,
/// then generates a day-by-day itinerary. Saved trips listed below.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Destination? _destination;
  late DateTimeRange _range;
  RangeValues _budget = const RangeValues(5000, 10000);
  final Set<String> _styles = {};
  Future<List<TripItinerary>>? _tripsFuture;
  bool _dataReady = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    // Default: a 5-day trip starting next week.
    _range = DateTimeRange(
      start: base.add(const Duration(days: 7)),
      end: base.add(const Duration(days: 11)),
    );
    DataService().load().then((_) {
      if (!mounted) return;
      setState(() => _dataReady = true);
    });
    _refreshTrips();
  }

  void _refreshTrips() {
    setState(() {
      _tripsFuture = loadSavedItineraries();
    });
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked != null && mounted) {
      setState(() => _range = picked);
    }
  }

  void _createTrip() {
    final destination = _destination;
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a destination first')),
      );
      return;
    }
    final itinerary = buildItinerary(
      id: const Uuid().v4(),
      destination: destination,
      start: _range.start,
      end: _range.end,
      budgetMin: _budget.start,
      budgetMax: _budget.end,
      styles: _styles.toList(),
    );
    Navigator.of(context)
        .push(
          MaterialPageRoute(
              builder: (_) => ItineraryScreen(itinerary: itinerary)),
        )
        .then((_) => _refreshTrips());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('Plan Your Trip',
                style: BohoFonts.script(34, color: BohoColors.espresso)),
            const SizedBox(height: 4),
            Text('Create your perfect Philippine adventure.',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.75))),
            const SizedBox(height: 18),
            _formCard(),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Create My Trip',
              onPressed: _dataReady ? _createTrip : null,
            ),
            const SizedBox(height: 26),
            SectionHeader(title: 'My Trips'),
            const SizedBox(height: 10),
            _myTrips(),
          ],
        ),
      ),
    );
  }

  Widget _formCard() {
    final destinations = DataService().destinations;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Where are you going?'),
          const SizedBox(height: 8),
          DropdownButtonFormField<Destination>(
            initialValue: _destination,
            hint: Text('Select a destination',
                style: BohoFonts.body(14,
                    color: BohoColors.espresso.withValues(alpha: 0.5))),
            items: [
              for (final d in destinations)
                DropdownMenuItem(
                  value: d,
                  child: Text('${d.name}, ${d.province}',
                      style: BohoFonts.body(14, color: BohoColors.espresso)),
                ),
            ],
            onChanged: (d) => setState(() => _destination = d),
          ),
          const SizedBox(height: 16),
          _label('When?'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.calendar_month_rounded,
                  color: BohoColors.forest),
              label: Text(
                '${formatTripDate(_range.start)} - ${formatTripDate(_range.end)}',
                style: BohoFonts.body(14,
                    color: BohoColors.espresso, weight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: BohoColors.tan, width: 1.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('Budget'),
          const SizedBox(height: 8),
          Text(
            '${formatPhp(_budget.start)} - ${formatPhp(_budget.end)}',
            style: BohoFonts.heading(18, color: BohoColors.terracotta),
          ),
          RangeSlider(
            values: _budget,
            min: 3000,
            max: 30000,
            divisions: 27,
            labels: RangeLabels(
              formatPhp(_budget.start),
              formatPhp(_budget.end),
            ),
            activeColor: BohoColors.forest,
            inactiveColor: BohoColors.tan,
            onChanged: (v) => setState(() => _budget = v),
          ),
          const SizedBox(height: 8),
          _label('Travel style'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _styleOptions)
                FilterChip(
                  label: Text(s,
                      style: BohoFonts.body(13,
                          color: _styles.contains(s)
                              ? Colors.white
                              : BohoColors.espresso,
                          weight: FontWeight.w700)),
                  selected: _styles.contains(s),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _styles.add(s);
                    } else {
                      _styles.remove(s);
                    }
                  }),
                  selectedColor: BohoColors.forest,
                  backgroundColor: BohoColors.tan.withValues(alpha: 0.4),
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _styles.contains(s)
                          ? BohoColors.forest
                          : BohoColors.tan,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: BohoFonts.heading(15, color: BohoColors.espresso));

  Widget _myTrips() {
    return FutureBuilder<List<TripItinerary>>(
      future: _tripsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: BohoColors.forest)),
          );
        }
        final trips = snap.data ?? [];
        if (trips.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BohoColors.tan, width: 1.2),
            ),
            child: Text('No saved trips yet. Plan your first one above!',
                style: BohoFonts.body(14,
                    color: BohoColors.espresso.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
          );
        }
        return Column(
          children: [
            for (final trip in trips)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => ItineraryScreen(itinerary: trip)))
                      .then((_) => _refreshTrips());
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BohoColors.tan, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: BohoColors.forest.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.map_rounded,
                            color: BohoColors.forest),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip.destinationName,
                                style: BohoFonts.heading(16,
                                    color: BohoColors.espresso)),
                            const SizedBox(height: 2),
                            Text(
                              '${trip.dateLabel} · ${trip.dayCount} Days',
                              style: BohoFonts.body(13,
                                  color: BohoColors.espresso
                                      .withValues(alpha: 0.65)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: BohoColors.espresso),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
