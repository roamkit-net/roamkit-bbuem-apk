import 'package:flutter/material.dart';

import 'home_tokens.dart';

class HomeRefreshIcon extends StatefulWidget {
  const HomeRefreshIcon({super.key, required this.spinning});

  final bool spinning;

  @override
  State<HomeRefreshIcon> createState() => _HomeRefreshIconState();
}

class _HomeRefreshIconState extends State<HomeRefreshIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.spinning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant HomeRefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning) {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final icon = const Icon(Icons.refresh, color: HomeTokens.primaryText);
    if (!widget.spinning || reduceMotion) {
      return icon;
    }
    return RotationTransition(turns: _controller, child: icon);
  }
}
