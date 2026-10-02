// GoTRVL PH admin: Places — fix pins and place info without a new build.
//
// SECURITY MODEL: admin role is a Firebase Auth custom claim only,
// enforced server-side by Firestore security rules. This screen assumes
// the signed-in user already carries the admin claim; the rules reject
// any write from a non-admin client.
//
// How it works: quest places ship in the app bundle (quest_places.json).
// Edits here are stored as overrides in Firestore `place_overrides` and
// merged over the bundled data by QuestService on next app start, so a
// corrected coordinate goes live without shipping an APK.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/place_override_service.dart';
import '../services/quest_service.dart';
import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// Admin "Places" section: searchable pin list + per-place editor.
class AdminPlacesScreen extends StatefulWidget {
  const AdminPlacesScreen({super.key});

  @override
  State<AdminPlacesScreen> createState() => _AdminPlacesScreenState();
}

class _AdminPlacesScreenState extends State<AdminPlacesScreen> {
  final _searchC = TextEditingController();
  String _query = '';
  String _bucket =
      'all'; // all | edited | where_to_go | things_to_do | where_to_eat
  bool _loading = true;
  List<QuestPlace> _places = [];
  Set<String> _overriddenIds = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await QuestService().load();
    Map<String, Map<String, dynamic>> overrides = {};
    try {
      overrides = await PlaceOverrideService().fetchOverrides();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _places = QuestService().all;
      _overriddenIds = overrides.keys.toSet();
      _loading = false;
    });
  }

  List<QuestPlace> get _filtered {
    final q = _query.trim().toLowerCase();
    return _places.where((p) {
      if (_bucket == 'edited' && !_overriddenIds.contains(p.id)) return false;
      if (_bucket != 'all' && _bucket != 'edited' && p.filter != _bucket)
        return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.destination.toLowerCase().contains(q) ||
          p.province.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Places')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _searchC,
              decoration: InputDecoration(
                hintText: 'Search 371 pins by name or place…',
                prefixIcon: const Icon(Icons.search_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('all', 'All'),
                _chip('edited', '✏️ Edited'),
                _chip('where_to_go', 'Where to go'),
                _chip('things_to_do', 'Things to do'),
                _chip('where_to_eat', 'Where to eat'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const AdminEmptyState(
                        icon: Icons.pin_drop_outlined,
                        message:
                            'No pins match. Try a different search.')
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) => _placeRow(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _bucket == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _bucket = value),
      ),
    );
  }

  Widget _placeRow(QuestPlace p) {
    final edited = _overriddenIds.contains(p.id);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            edited ? BohoColors.sun : BohoColors.tan.withValues(alpha: 0.5),
        child: Text(
          p.filter == 'where_to_eat'
              ? '🍚'
              : p.filter == 'things_to_do'
                  ? '🎯'
                  : '📍',
          style: const TextStyle(fontSize: 18),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (edited)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BohoColors.sun.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('EDITED',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      subtitle: Text(
          '${p.destination} · ${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
              builder: (_) => _PlaceEditor(place: p, edited: edited)),
        );
        if (changed == true) _reload();
      },
    );
  }
}

/// Per-place editor: name, coordinates, category, points, address, blurb.
/// Saves an override doc; "Revert" deletes it and restores bundled data.
class _PlaceEditor extends StatefulWidget {
  final QuestPlace place;
  final bool edited;
  const _PlaceEditor({required this.place, required this.edited});

  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  late final TextEditingController _nameC;
  late final TextEditingController _latC;
  late final TextEditingController _lngC;
  late final TextEditingController _addrC;
  late final TextEditingController _blurbC;
  late final TextEditingController _pointsC;
  late String _filter;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    _nameC = TextEditingController(text: p.name);
    _latC = TextEditingController(text: p.lat.toString());
    _lngC = TextEditingController(text: p.lng.toString());
    _addrC = TextEditingController(text: p.address);
    _blurbC = TextEditingController(text: p.blurb);
    _pointsC = TextEditingController(text: p.points.toString());
    _filter = p.filter;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _latC.dispose();
    _lngC.dispose();
    _addrC.dispose();
    _blurbC.dispose();
    _pointsC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final fields = <String, dynamic>{
      'name': _nameC.text.trim(),
      'lat': _latC.text.trim(),
      'lng': _lngC.text.trim(),
      'address': _addrC.text.trim(),
      'blurb': _blurbC.text.trim(),
      'filter': _filter,
      'points': _pointsC.text.trim(),
    };
    final error = PlaceOverrideService.validateFields(fields);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _busy = true);
    try {
      // Store numbers as numbers so the merge never has to re-parse.
      fields['lat'] = double.parse(_latC.text.trim());
      fields['lng'] = double.parse(_lngC.text.trim());
      fields['points'] = int.parse(_pointsC.text.trim());
      await PlaceOverrideService().saveOverride(widget.place.id, fields);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved. Pins update on next app start.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Could not save: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  Future<void> _revert() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (cctx) => AlertDialog(
        title: const Text('Revert to bundled data?'),
        content: const Text('Your edits for this pin will be discarded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(cctx).pop(false),
              child: const Text('Keep edits')),
          TextButton(
              onPressed: () => Navigator.of(cctx).pop(true),
              child: const Text('Revert')),
        ],
      ),
    );
    if (confirm != true || _busy) return;
    setState(() => _busy = true);
    try {
      await PlaceOverrideService().deleteOverride(widget.place.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not revert.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    return Scaffold(
      appBar: AppBar(title: Text('Edit pin', maxLines: 1)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AdminSectionTitle('Identity'),
          _field(_nameC, 'Place name'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _field(_latC, 'Latitude',
                      hint: 'e.g. 11.9674',
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true, signed: true))),
              const SizedBox(width: 10),
              Expanded(
                  child: _field(_lngC, 'Longitude',
                      hint: 'e.g. 121.9248',
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true, signed: true))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              'Bundled: ${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)} · must stay inside the Philippines',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 14),
          AdminSectionTitle('Category & points'),
          DropdownButtonFormField<String>(
            initialValue: _filter,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'Category'),
            items: const [
              DropdownMenuItem(
                  value: 'where_to_go', child: Text('📍 Where to go')),
              DropdownMenuItem(
                  value: 'things_to_do', child: Text('🎯 Things to do')),
              DropdownMenuItem(
                  value: 'where_to_eat', child: Text('🍚 Where to eat')),
            ],
            onChanged: (v) => setState(() => _filter = v ?? _filter),
          ),
          const SizedBox(height: 10),
          _field(_pointsC, 'Points (100–1000)',
              keyboard: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 14),
          AdminSectionTitle('Details'),
          _field(_addrC, 'Address'),
          const SizedBox(height: 10),
          _field(_blurbC, 'Description', maxLines: 4),
          const SizedBox(height: 6),
          Text('Province: ${p.province} · Destination: ${p.destination}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save changes'),
          ),
          if (widget.edited) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _revert,
              child: const Text('Revert to bundled data',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('place_overrides')
                .doc(p.id)
                .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              if (data == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    'Last edited: ${data['updatedAt'] ?? '—'} by ${data['updatedBy'] ?? '—'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {String? hint,
      TextInputType? keyboard,
      int maxLines = 1,
      List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
          border: const OutlineInputBorder(), labelText: label, hintText: hint),
      keyboardType: keyboard,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
    );
  }
}
