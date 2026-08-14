import 'package:flutter/material.dart';

import 'home_tokens.dart';

class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.semanticButton = false,
    this.semanticHint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool semanticButton;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: HomeTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HomeTokens.cardRadius),
        side: const BorderSide(color: HomeTokens.border),
      ),
      child: child,
    );
    final tappable = onTap == null
        ? card
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(HomeTokens.cardRadius),
            child: card,
          );
    if (semanticLabel == null) {
      return tappable;
    }
    return Semantics(
      button: semanticButton || onTap != null,
      label: semanticLabel,
      hint: semanticHint,
      child: tappable,
    );
  }
}

class HomeCircleIcon extends StatelessWidget {
  const HomeCircleIcon({
    super.key,
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HomeTokens.iconCircle,
      height: HomeTokens.iconCircle,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
