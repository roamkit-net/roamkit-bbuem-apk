import 'package:flutter/material.dart';

import '../status/expiry_countdown.dart';
import 'home_card.dart';
import 'home_tokens.dart';

class HomeExpiryCard extends StatelessWidget {
  const HomeExpiryCard({
    super.key,
    required this.expiresAt,
    required this.now,
  });

  final DateTime? expiresAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (expiresAt == null) {
      return const SizedBox.shrink();
    }
    final countdown = buildExpiryCountdown(
      expiresAt: expiresAt,
      now: now,
      notYetInUse: false,
    );
    final remaining = countdown.isExpired ? 'Expired' : countdown.remainingLine;

    return HomeCard(
      semanticLabel: 'Expires ${countdown.dateLine}. $remaining',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            const HomeCircleIcon(
              icon: Icons.calendar_today,
              color: HomeTokens.expiry,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expires ${countdown.dateLine}',
                    style: const TextStyle(
                      color: HomeTokens.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    remaining,
                    style: TextStyle(
                      color: countdown.isExpired
                          ? HomeTokens.expiry
                          : HomeTokens.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
