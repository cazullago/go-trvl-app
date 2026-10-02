import 'package:flutter/material.dart';
import '../models/monetization_models.dart';

/// Future gating point for premium traveler features.
///
/// Today nothing is paywalled: this is a pass-through that always returns
/// [child]. When a premium membership launches, this is the single place
/// where the gate gets enforced (see PremiumService, currently a stub).
/// Core travel features must stay free forever, so only genuinely extra
/// features may ever be wrapped with this gate.
class PremiumGate extends StatelessWidget {
  final PremiumFeature feature;
  final Widget child;

  const PremiumGate({
    super.key,
    required this.feature,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
