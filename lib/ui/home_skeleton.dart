import 'package:flutter/material.dart';

import 'home_card.dart';
import 'home_tokens.dart';

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({
    super.key,
    required this.showHero,
    required this.showPackages,
  });

  final bool showHero;
  final bool showPackages;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shimmer(
      enabled: !reduceMotion,
      child: Column(
        children: [
          if (showHero) ...[
            const HomeCard(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  children: [
                    _Bar(width: 140, height: 22),
                    SizedBox(height: 16),
                    _Bar(width: 220, height: 18),
                    SizedBox(height: 28),
                    _Circle(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HomeTokens.cardGap),
            const _RowCard(),
            const SizedBox(height: HomeTokens.cardGap),
            const _RowCard(),
            const SizedBox(height: HomeTokens.cardGap),
          ],
          if (showPackages) const _RowCard(tall: true),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HomeTokens.skeleton,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: const BoxDecoration(
        color: HomeTokens.skeleton,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({this.tall = false});

  final bool tall;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: SizedBox(
        height: tall ? 88 : 72,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _CircleDot(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bar(width: 120, height: 14),
                    SizedBox(height: 8),
                    _Bar(width: 180, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleDot extends StatelessWidget {
  const _CircleDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HomeTokens.iconCircle,
      height: HomeTokens.iconCircle,
      decoration: const BoxDecoration(
        color: HomeTokens.skeleton,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
      child: widget.child,
    );
  }
}
