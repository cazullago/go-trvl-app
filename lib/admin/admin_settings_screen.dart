// GoTRVL PH admin: remote feature flags.
//
// SECURITY MODEL: admin access is a Firebase Auth custom claim only,
// enforced server-side by Firestore security rules. This screen assumes the
// signed-in user already carries the admin claim; the rules reject any
// write from a non-admin client.
//
// IMPORTANT: this screen only edits the flags document. It does NOT modify
// any existing services. A coordinator will wire these flags into
// AffiliateService, AdService, the live flow and the premium flow.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// Remote feature flags stored in the app_config/global document.
///
/// Defaults (used when the document or a field does not exist):
/// - affiliatesEnabled: false. Matches AffiliateConfig.affiliatesEnabled;
///   partner deal buttons only show once real partner IDs are set.
/// - adsEnabled: true. Labeled travel ad slots are already live in the app.
/// - liveEnabled: true. The creator LIVE go-live flow is live.
/// - premiumComingSoon: true. The premium screen currently shows a
///   coming-soon placeholder; checkout is not wired yet.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _FlagDef {
  final String key;
  final String title;
  final String subtitle;

  const _FlagDef(this.key, this.title, this.subtitle);
}

const _flags = [
  _FlagDef(
    'affiliatesEnabled',
    'Affiliate links',
    'Show partner deal buttons when real partner IDs are set.',
  ),
  _FlagDef(
    'adsEnabled',
    'Ads',
    'Show labeled travel advertising slots.',
  ),
  _FlagDef(
    'liveEnabled',
    'Live streaming',
    'Allow creators to go live.',
  ),
  _FlagDef(
    'premiumComingSoon',
    'Premium coming soon',
    'Show the premium coming-soon screen instead of checkout.',
  ),
];

const _defaults = <String, bool>{
  'affiliatesEnabled': false,
  'adsEnabled': true,
  'liveEnabled': true,
  'premiumComingSoon': true,
};

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _docFuture;
  final Map<String, bool> _values = Map.of(_defaults);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _docFuture =
        FirebaseFirestore.instance.collection('app_config').doc('global').get();
    // Apply remote values once when the read completes; defaults stand in
    // when the document or a field does not exist.
    _docFuture.then((doc) {
      if (!mounted) return;
      setState(() => _applyRemote(doc.data()));
    });
  }

  void _applyRemote(Map<String, dynamic>? data) {
    if (data == null) return;
    for (final key in _defaults.keys) {
      final v = data[key];
      if (v is bool) _values[key] = v;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('global')
          .set(Map<String, bool>.of(_values), SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _docFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              message: 'Could not load settings: ${snapshot.error}',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BohoDecor.card(),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: BohoColors.dustyBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Changes apply without a new app build; the app '
                        're-reads this on launch.',
                        style: BohoFonts.body(14,
                            color: BohoColors.espresso.withValues(alpha: 0.75)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AdminSectionTitle('Feature flags'),
              Container(
                decoration: BohoDecor.card(),
                child: Column(
                  children: [
                    for (int i = 0; i < _flags.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: BohoColors.sandDark),
                      _FlagRow(
                        def: _flags[i],
                        value: _values[_flags[i].key] ?? false,
                        onChanged: (v) =>
                            setState(() => _values[_flags[i].key] = v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save settings'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  final _FlagDef def;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlagRow({
    required this.def,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: BohoColors.forest,
      title: Text(def.title, style: BohoFonts.heading(15)),
      subtitle: Text(
        def.subtitle,
        style: BohoFonts.body(12,
            color: BohoColors.espresso.withValues(alpha: 0.6)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
