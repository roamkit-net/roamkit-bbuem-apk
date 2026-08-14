import 'package:flutter/material.dart';

import '../status/usage_bar_view.dart';

class UsageBarWidget extends StatelessWidget {
  const UsageBarWidget({
    super.key,
    required this.bar,
    required this.color,
  });

  final UsageBarView bar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (bar.kind == UsageBarKind.unlimited) {
      return Column(
        children: [
          _track(fill: 1, fillColor: _fillColor(UsageBarColor.grey)),
          const SizedBox(height: 10),
          Text(
            'Unlimited',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (bar.kind != UsageBarKind.metered) {
      return Text(
        'Usage not synced',
        textAlign: TextAlign.center,
        style: textTheme.titleMedium?.copyWith(
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final percent = bar.remainingPercent ?? 0;
    final fraction = ((bar.remainingMb ?? 0) / (bar.totalMb ?? 1)).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.data_usage, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              'DATA REMAINING',
              style: textTheme.labelLarge?.copyWith(
                color: color.withValues(alpha: 0.8),
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          usageRemainingCaption(bar),
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _track(fill: fraction, fillColor: _fillColor(bar.color)),
        const SizedBox(height: 10),
        Text(
          usageUsedCaption(bar),
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _track({required double fill, required Color fillColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color.withValues(alpha: 0.25)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: ColoredBox(color: fillColor),
            ),
          ],
        ),
      ),
    );
  }

  Color _fillColor(UsageBarColor kind) {
    return switch (kind) {
      UsageBarColor.green => const Color(0xFFBBF7D0),
      UsageBarColor.orange => const Color(0xFFFBBF24),
      UsageBarColor.red => const Color(0xFFF87171),
      UsageBarColor.grey => color.withValues(alpha: 0.45),
    };
  }
}
