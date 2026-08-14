import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'home_card.dart';
import 'home_tokens.dart';

class HomeIccidCard extends StatelessWidget {
  const HomeIccidCard({
    super.key,
    required this.iccid,
    required this.copied,
    required this.onCopied,
  });

  final String iccid;
  final bool copied;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final value = iccid.trim();
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return HomeCard(
      semanticLabel: 'ICCID $value',
      semanticHint: 'Double tap to copy',
      semanticButton: true,
      onTap: () => _copy(context, value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            const HomeCircleIcon(icon: Icons.sim_card, color: HomeTokens.iccid),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ICCID',
                    style: TextStyle(
                      color: HomeTokens.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    softWrap: true,
                    style: const TextStyle(
                      color: HomeTokens.primaryText,
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: HomeTokens.actionGap),
            SizedBox(
              width: HomeTokens.minTap,
              height: HomeTokens.minTap,
              child: Tooltip(
                message: 'Copy ICCID',
                child: Icon(
                  copied ? Icons.check : Icons.copy_outlined,
                  color: HomeTokens.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copy(BuildContext context, String value) {
    onCopied();
    unawaited(Clipboard.setData(ClipboardData(text: value)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ICCID copied')),
    );
    SemanticsService.announce('ICCID copied', TextDirection.ltr);
  }
}
