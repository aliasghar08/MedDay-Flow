import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pure-Flutter staggered entrance animation and micro-interaction toolkit.
/// Built with zero third-party packages for buttery-smooth 60/120 FPS transitions.

/// Auto-animates a column of children with staggered interval delays.
class StaggeredColumn extends StatefulWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final Duration staggerDelay;
  final Duration maxStaggerCap;
  final Duration itemDuration;
  final Curve curve;

  const StaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.staggerDelay = const Duration(milliseconds: 45),
    this.maxStaggerCap = const Duration(milliseconds: 450),
    this.itemDuration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<StaggeredColumn> createState() => _StaggeredColumnState();
}

class _StaggeredColumnState extends State<StaggeredColumn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final childCount = widget.children.length;
    final totalStaggerMs = math.min(
      childCount * widget.staggerDelay.inMilliseconds,
      widget.maxStaggerCap.inMilliseconds,
    );
    final totalDurationMs = totalStaggerMs + widget.itemDuration.inMilliseconds;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: math.max(totalDurationMs, 100)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _controller.duration!.inMilliseconds;
    final count = widget.children.length;

    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisAlignment: widget.mainAxisAlignment,
      mainAxisSize: widget.mainAxisSize,
      children: List.generate(count, (index) {
        final startDelayMs = math.min(
          index * widget.staggerDelay.inMilliseconds,
          widget.maxStaggerCap.inMilliseconds,
        );
        final endMs = math.min(
          startDelayMs + widget.itemDuration.inMilliseconds,
          totalMs,
        );

        final startInterval = (startDelayMs / totalMs).clamp(0.0, 1.0);
        final endInterval = (endMs / totalMs).clamp(startInterval + 0.01, 1.0);

        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(startInterval, endInterval, curve: widget.curve),
        );

        return StaggeredItem(
          animation: animation,
          child: widget.children[index],
        );
      }),
    );
  }
}

/// A staggered animation item that combines a fade (0.0 -> 1.0) and
/// subtle upward slide (Offset(0, 0.04) -> Offset.zero).
class StaggeredItem extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const StaggeredItem({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: slideAnim,
        child: child,
      ),
    );
  }
}

/// Standalone auto-animating staggered entrance widget for ListViews,
/// Grids, or standalone dynamic cards.
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration staggerDelay;
  final Duration maxStaggerCap;
  final Duration itemDuration;
  final Curve curve;
  final Offset startOffset;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 45),
    this.maxStaggerCap = const Duration(milliseconds: 450),
    this.itemDuration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
    this.startOffset = const Offset(0, 0.04),
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final delayMs = math.min(
      widget.index * widget.staggerDelay.inMilliseconds,
      widget.maxStaggerCap.inMilliseconds,
    );

    _controller = AnimationController(
      vsync: this,
      duration: widget.itemDuration,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(begin: widget.startOffset, end: Offset.zero).animate(curved);

    if (delayMs == 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Micro-interaction widget that scales down to 0.97 on press with light tactile haptics.
class TactilePressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double targetScale;
  final Duration duration;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const TactilePressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.targetScale = 0.97,
    this.duration = const Duration(milliseconds: 110),
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<TactilePressScale> createState() => _TactilePressScaleState();
}

class _TactilePressScaleState extends State<TactilePressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.targetScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Wraps loading -> loaded content transitions with a buttery-smooth fade dissolve.
class SmoothContentSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const SmoothContentSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: child,
    );
  }
}
