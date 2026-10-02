import 'package:flutter/material.dart';

import '../services/billing_service.dart';

/// A purchase-option label that shows the store's real localized price when
/// the product is configured (e.g. "Unlock now · ₱149"), and falls back to a
/// neutral label with no amount when it is not. Unconfirmed prices are never
/// shown: the Play/App Store purchase dialog always shows the real price at
/// checkout anyway.
class StorePriceText extends StatelessWidget {
  final String productId;
  final String label;
  final TextStyle? style;
  final String separator;

  /// Text appended after the price (or after the label when no price is
  /// known), e.g. ': whole map unlocked'.
  final String trailing;

  const StorePriceText({
    super.key,
    required this.productId,
    required this.label,
    this.style,
    this.separator = ' · ',
    this.trailing = '',
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: BillingService().priceOf(productId),
      builder: (context, snap) {
        final price = snap.data;
        final text = (price != null && price.isNotEmpty)
            ? '$label$separator$price$trailing'
            : '$label$trailing';
        return Text(text, style: style);
      },
    );
  }
}
