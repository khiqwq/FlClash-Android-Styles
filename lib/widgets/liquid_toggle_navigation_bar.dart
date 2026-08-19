// Adapted from AndroidLiquidGlass LiquidToggle.kt at commit b18eb0ff.
// Copyright AndroidLiquidGlass contributors. Licensed under Apache-2.0.
// Modified for Flutter and multi-destination navigation by FlClash contributors.

import 'dart:math';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/models/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:intl/intl.dart' as intl;

import 'effect.dart';

typedef LiquidNavigationSelected = void Function(int index);

class LiquidToggleNavigationBar extends StatefulWidget {
  final List<NavigationItem> items;
  final int selectedIndex;
  final LiquidNavigationSelected onSelected;

  const LiquidToggleNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<LiquidToggleNavigationBar> createState() =>
      _LiquidToggleNavigationBarState();
}

class _LiquidToggleNavigationBarState extends State<LiquidToggleNavigationBar>
    with TickerProviderStateMixin {
  late final AnimationController _positionController;
  late final AnimationController _pressController;
  late final SpringDescription _positionSpring;

  double _cellWidth = 0;
  double _dragVelocity = 0;
  bool _dragging = false;
  int? _pendingSelection;

  @override
  void initState() {
    super.initState();
    _positionSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 300,
      ratio: 1,
    );
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    )..addListener(_rebuild);
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 220),
    )..addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant LiquidToggleNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.selectedIndex != widget.selectedIndex) {
      if (_pendingSelection == widget.selectedIndex) {
        _pendingSelection = null;
        return;
      }
      _animatePosition(widget.selectedIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _positionController
      ..removeListener(_rebuild)
      ..dispose();
    _pressController
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  void _animatePosition(double target, [double velocity = 0]) {
    _positionController.animateWith(
      SpringSimulation(
        _positionSpring,
        _positionController.value,
        target,
        velocity,
      ),
    );
  }

  void _beginPress() {
    _pressController.forward();
  }

  void _endPress() {
    _pressController.reverse();
  }

  void _select(int index) {
    _dragging = false;
    _dragVelocity = 0;
    _animatePosition(index.toDouble());
    _notifySelection(index);
  }

  void _notifySelection(int index) {
    _pendingSelection = index;
    widget.onSelected(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pendingSelection == index) {
        _pendingSelection = null;
      }
    });
  }

  void _handleDragStart(DragStartDetails details) {
    _dragging = true;
    _dragVelocity = 0;
    _positionController.stop();
    _beginPress();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_cellWidth <= 0 || widget.items.isEmpty) {
      return;
    }
    if (_pressController.value == 0 && !_pressController.isAnimating) {
      _beginPress();
    }
    final direction = Directionality.of(context);
    final directionFactor = direction == TextDirection.ltr ? 1.0 : -1.0;
    final delta = details.delta.dx / _cellWidth * directionFactor;
    _dragVelocity = delta;
    _positionController.value = (_positionController.value + delta).clamp(
      0.0,
      max(widget.items.length - 1, 0).toDouble(),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_cellWidth <= 0 || widget.items.isEmpty) {
      _dragging = false;
      _endPress();
      return;
    }
    final direction = Directionality.of(context);
    final directionFactor = direction == TextDirection.ltr ? 1.0 : -1.0;
    final velocity =
        (details.primaryVelocity ?? 0) / _cellWidth * directionFactor;
    final target = _positionController.value.round().clamp(
      0,
      widget.items.length - 1,
    );
    _dragging = false;
    _dragVelocity = 0;
    _animatePosition(target.toDouble(), velocity);
    _notifySelection(target);
    _endPress();
  }

  void _handleDragCancel() {
    _dragging = false;
    _dragVelocity = 0;
    _animatePosition(widget.selectedIndex.toDouble());
    _endPress();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final trackColor = isDark
        ? const Color(0xFF787880).withValues(alpha: 0.36)
        : const Color(0xFF787878).withValues(alpha: 0.2);
    final progress = _pressController.value;
    final velocity = (_dragVelocity / 10).clamp(-0.2, 0.2);
    final baseScale = 1 + 0.5 * progress;
    final scaleX = baseScale / (1 - velocity * 0.75);
    final scaleY = baseScale * (1 - velocity * 0.25);
    final thumbColor = Colors.white.withValues(alpha: 1 - progress);
    final radius = BorderRadius.circular(28);

    return SizedBox(
      key: const ValueKey('liquid-toggle-navigation'),
      height: AndroidAppearanceTokens.miuixNavigationBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _cellWidth = (constraints.maxWidth - 8) / widget.items.length;
          final maxPosition = max(widget.items.length - 1, 0).toDouble();
          final position = _positionController.value.clamp(0.0, maxPosition);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: AndroidGlassSurface(
              blur: true,
              liquidGlass: false,
              surfaceColor: trackColor,
              borderRadius: radius,
              shape: const StadiumBorder(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: [
                      for (var index = 0; index < widget.items.length; index++)
                        Expanded(
                          child: _LiquidNavigationItem(
                            item: widget.items[index],
                            selected: index == widget.selectedIndex,
                            onPressed: () => _select(index),
                          ),
                        ),
                    ],
                  ),
                  PositionedDirectional(
                    start: 8 + position * _cellWidth,
                    top: 6,
                    width: max(_cellWidth - 8, 1),
                    height: 56,
                    child: Transform.scale(
                      key: const ValueKey('liquid-toggle-thumb-transform'),
                      scaleX: scaleX,
                      scaleY: scaleY,
                      transformHitTests: false,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) => _beginPress(),
                          onPointerUp: (_) => _endPress(),
                          onPointerCancel: (_) => _handleDragCancel(),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _select(widget.selectedIndex),
                            onHorizontalDragStart: _handleDragStart,
                            onHorizontalDragUpdate: _handleDragUpdate,
                            onHorizontalDragEnd: _handleDragEnd,
                            onHorizontalDragCancel: _handleDragCancel,
                            child: AndroidGlassSurface(
                              blur: false,
                              liquidGlass: true,
                              liquidProgress: progress,
                              surfaceColor: thumbColor,
                              borderRadius: radius,
                              shape: const StadiumBorder(),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: radius,
                                  border: Border.all(
                                    color: Colors.black.withValues(
                                      alpha: 0.15 * progress,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LiquidNavigationItem extends StatelessWidget {
  final NavigationItem item;
  final bool selected;
  final VoidCallback onPressed;

  const _LiquidNavigationItem({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.colorScheme.primary
        : context.colorScheme.onSurfaceVariant;
    final label = intl.Intl.message(item.label.name);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme.merge(
              data: IconThemeData(size: 25, color: color),
              child: item.icon,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 11,
                height: 1.15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
