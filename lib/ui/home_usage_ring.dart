import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../status/usage_bar_view.dart';
import 'home_tokens.dart';

class HomeUsageRing extends StatelessWidget {
  const HomeUsageRing({super.key, required this.bar});

  final UsageBarView bar;

  @override
  Widget build(BuildContext context) {
    if (bar.kind == UsageBarKind.unavailable) {
      return const SizedBox.shrink();
    }

    final remaining = bar.kind == UsageBarKind.unlimited
        ? 'Unlimited'
        : formatDataMb(bar.remainingMb!);
    final ofTotal = bar.kind == UsageBarKind.unlimited
        ? null
        : 'of ${formatDataMb(bar.totalMb!)} remaining';
    final percent = bar.remainingPercent;
    final used = usageUsedCaption(bar);
    final remainCaption = bar.kind == UsageBarKind.unlimited
        ? null
        : '${formatDataMb(bar.remainingMb!)} remaining';

    final semantics = bar.kind == UsageBarKind.unlimited
        ? 'Unlimited data remaining'
        : '${formatDataMb(bar.remainingMb!)} of ${formatDataMb(bar.totalMb!)} remaining'
            .replaceAll('GB', 'gigabytes')
            .replaceAll('MB', 'megabytes');

    return Semantics(
      label: semantics,
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _RingPainter(
                remainingFraction: bar.kind == UsageBarKind.unlimited
                    ? 1
                    : (percent ?? 0) / 100,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        remaining,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: HomeTokens.remaining,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (ofTotal != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          ofTotal,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: HomeTokens.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (percent != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: HomeTokens.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (used.isNotEmpty || remainCaption != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    used,
                    style: const TextStyle(
                      color: HomeTokens.used,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (remainCaption != null)
                  Text(
                    remainCaption,
                    style: const TextStyle(
                      color: HomeTokens.remaining,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.remainingFraction});

  final double remainingFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const stroke = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final bg = Paint()
      ..color = HomeTokens.used
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = HomeTokens.remaining
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bg);
    final sweep = (remainingFraction.clamp(0.0, 1.0)) * math.pi * 2;
    if (sweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fg);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.remainingFraction != remainingFraction;
  }
}
