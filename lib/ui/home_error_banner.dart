import 'package:flutter/material.dart';

import 'home_tokens.dart';

class HomeErrorBanner extends StatelessWidget {
  const HomeErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeTokens.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            const Text(
              '!',
              style: TextStyle(
                color: HomeTokens.error,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: HomeTokens.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: HomeTokens.actionGap),
            SizedBox(
              height: HomeTokens.minTap,
              child: TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: HomeTokens.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
