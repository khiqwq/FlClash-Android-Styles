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
  late final AnimationController _indicatorScaleXController;
  late final AnimationController _indicatorScaleYController;
  late final AnimationController _panelOffsetController;
  late final SpringDescription _positionSpring;
  late final SpringDescription _pressSpring;
  late final SpringDescription _indicatorScaleXSpring;
  late final SpringDescription _indicatorScaleYSpring;
  late final SpringDescription _panelOffsetSpring;

  double _cellWidth = 0;
  double _dragVelocity = 0;
  bool _dragging = false;
  int? _pendingSelection;
  int _interactionGeneration = 0;
  Offset? _lastDragPosition;

  @override
  void initState() {
    super.initState();
    _positionSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 1000,
      ratio: 1,
    );
    _pressSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 1000,
      ratio: 1,
    );
    _indicatorScaleXSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 250,
      ratio: 0.6,
    );
    _indicatorScaleYSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 250,
      ratio: 0.7,
    );
    _panelOffsetSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 300,
      ratio: 1,
    );
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    )..addListener(_rebuild);
    _pressController = AnimationController(vsync: this, value: 0)
      ..addListener(_rebuild);
    _indicatorScaleXController = AnimationController.unbounded(
      vsync: this,
      value: 1,
    )..addListener(_rebuild);
    _indicatorScaleYController = AnimationController.unbounded(
      vsync: this,
      value: 1,
    )..addListener(_rebuild);
    _panelOffsetController = AnimationController.unbounded(vsync: this)
      ..addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant LiquidToggleNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.selectedIndex != widget.selectedIndex) {
      if (_pendingSelection == widget.selectedIndex) {
        _pendingSelection = null;
        return;
      }
      final positionAnimation = _animatePosition(
        widget.selectedIndex.toDouble(),
      );
      if (_pressController.value > 0 || _pressController.isAnimating) {
        _releasePressWhenSettled(positionAnimation);
      }
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
    _indicatorScaleXController
      ..removeListener(_rebuild)
      ..dispose();
    _indicatorScaleYController
      ..removeListener(_rebuild)
      ..dispose();
    _panelOffsetController
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  TickerFuture _animatePosition(double target, [double velocity = 0]) {
    _interactionGeneration++;
    return _positionController.animateWith(
      SpringSimulation(
        _positionSpring,
        _positionController.value,
        target,
        velocity,
      ),
    );
  }

  void _beginPress() {
    _interactionGeneration++;
    _pressController.animateWith(
      SpringSimulation(_pressSpring, _pressController.value, 1, 0),
    );
    _indicatorScaleXController.animateWith(
      SpringSimulation(
        _indicatorScaleXSpring,
        _indicatorScaleXController.value,
        1.5,
        0,
      ),
    );
    _indicatorScaleYController.animateWith(
      SpringSimulation(
        _indicatorScaleYSpring,
        _indicatorScaleYController.value,
        1.5,
        0,
      ),
    );
  }

  void _releasePress() {
    _pressController.animateWith(
      SpringSimulation(_pressSpring, _pressController.value, 0, 0),
    );
    _indicatorScaleXController.animateWith(
      SpringSimulation(
        _indicatorScaleXSpring,
        _indicatorScaleXController.value,
        1,
        0,
      ),
    );
    _indicatorScaleYController.animateWith(
      SpringSimulation(
        _indicatorScaleYSpring,
        _indicatorScaleYController.value,
        1,
        0,
      ),
    );
  }

  void _releasePressWhenSettled(TickerFuture positionAnimation) {
    final generation = _interactionGeneration;
    positionAnimation.whenCompleteOrCancel(() {
      if (mounted && generation == _interactionGeneration) {
        _releasePress();
      }
    });
  }

  void _settlePanelOffset() {
    _panelOffsetController.animateWith(
      SpringSimulation(_panelOffsetSpring, _panelOffsetController.value, 0, 0),
    );
  }

  void _select(int index) {
    _dragging = false;
    _dragVelocity = 0;
    final positionAnimation = _animatePosition(index.toDouble());
    _settlePanelOffset();
    _notifySelection(index);
    if (_pressController.value > 0 || _pressController.isAnimating) {
      _releasePressWhenSettled(positionAnimation);
    }
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
    _lastDragPosition = details.globalPosition;
    _positionController.stop();
    _panelOffsetController.stop();
    if (_pressController.value == 0 && !_pressController.isAnimating) {
      _beginPress();
    }
  }

  bool _isInsideBar(Offset globalPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    final localPosition = renderObject.globalToLocal(globalPosition);
    return localPosition.dx >= 0 &&
        localPosition.dx <= renderObject.size.width &&
        localPosition.dy >= 0 &&
        localPosition.dy <= renderObject.size.height;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_cellWidth <= 0 || widget.items.isEmpty) {
      return;
    }
    final previousPosition = _lastDragPosition ?? details.globalPosition;
    _lastDragPosition = details.globalPosition;
    if (!_isInsideBar(previousPosition) ||
        !_isInsideBar(details.globalPosition)) {
      return;
    }
    if (_pressController.value == 0 && !_pressController.isAnimating) {
      _beginPress();
    }
    final direction = Directionality.of(context);
    final directionFactor = direction == TextDirection.ltr ? 1.0 : -1.0;
    final delta = details.delta.dx / _cellWidth * directionFactor;
    _dragVelocity = details.delta.dx * directionFactor;
    _panelOffsetController.value += details.delta.dx;
    _positionController.value = (_positionController.value + delta).clamp(
      0.0,
      max(widget.items.length - 1, 0).toDouble(),
    );
  }

  void _finishDrag([double velocity = 0]) {
    if (_cellWidth <= 0 || widget.items.isEmpty) {
      _dragging = false;
      _lastDragPosition = null;
      _settlePanelOffset();
      _releasePress();
      return;
    }
    final target = _positionController.value.round().clamp(
      0,
      widget.items.length - 1,
    );
    _dragging = false;
    _dragVelocity = 0;
    _lastDragPosition = null;
    final positionAnimation = _animatePosition(target.toDouble(), velocity);
    _settlePanelOffset();
    _notifySelection(target);
    _releasePressWhenSettled(positionAnimation);
  }

  void _handleDragEnd(DragEndDetails details) {
    final direction = Directionality.of(context);
    final directionFactor = direction == TextDirection.ltr ? 1.0 : -1.0;
    final velocity =
        (details.primaryVelocity ?? 0) / max(_cellWidth, 1) * directionFactor;
    _finishDrag(velocity);
  }

  void _handleDragCancel() {
    if (!_dragging) {
      _releasePress();
      return;
    }
    _finishDrag();
  }

  void _handleTapCancel() {
    final generation = _interactionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _interactionGeneration && !_dragging) {
        _releasePress();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xFF121212).withValues(alpha: 0.4)
        : const Color(0xFFFAFAFA).withValues(alpha: 0.4);
    final progress = _pressController.value;
    final velocity = (_dragVelocity / 10).clamp(-0.2, 0.2);
    final baseScale = 1 + 0.5 * progress;
    final scaleX = baseScale / (1 - velocity * 0.75);
    final scaleY = baseScale * (1 - velocity * 0.25);
    final thumbColor = Color.lerp(
      isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.1),
      Colors.black.withValues(alpha: 0.03),
      progress,
    )!;
    final panelRadius = BorderRadius.circular(32);
    final thumbRadius = BorderRadius.circular(28);

    return SizedBox(
      key: const ValueKey('liquid-toggle-navigation'),
      height: AndroidAppearanceTokens.liquidNavigationBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _cellWidth = (constraints.maxWidth - 8) / widget.items.length;
          final maxPosition = max(widget.items.length - 1, 0).toDouble();
          final position = _positionController.value.clamp(0.0, maxPosition);
          final panelScale = 1 + 16 / max(constraints.maxWidth, 1) * progress;
          final panelOffsetFraction =
              (_panelOffsetController.value / max(constraints.maxWidth, 1))
                  .clamp(-1.0, 1.0);
          final panelOffset =
              4 *
              panelOffsetFraction.sign *
              Curves.easeOut.transform(panelOffsetFraction.abs());
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(panelOffset, 0),
                  transformHitTests: false,
                  child: Transform.scale(
                    key: const ValueKey('liquid-toggle-panel-transform'),
                    scale: panelScale,
                    transformHitTests: false,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: panelRadius,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: AndroidGlassSurface(
                        blur: false,
                        liquidGlass: true,
                        liquidProgress: 1,
                        liquidAccentColor: Colors.transparent,
                        liquidBlurSigma: 4,
                        liquidRefractionHeight: 24,
                        liquidRefractionAmount: 24,
                        liquidChromaticAberration: 0,
                        scaleLiquidBlurWithProgress: false,
                        liquidSize: Size(
                          constraints.maxWidth,
                          AndroidAppearanceTokens.liquidNavigationBarHeight,
                        ),
                        surfaceColor: panelColor,
                        borderRadius: panelRadius,
                        shape: const StadiumBorder(),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(panelOffset, 0),
                  transformHitTests: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < widget.items.length;
                          index++
                        )
                          Expanded(
                            key: ValueKey('liquid-navigation-item-$index'),
                            child: _LiquidNavigationItem(
                              index: index,
                              item: widget.items[index],
                              selected: index == widget.selectedIndex,
                              selectionProgress: (1 - (position - index).abs())
                                  .clamp(0, 1),
                              pressProgress: progress,
                              onPressed: () => _select(index),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 4 + position * _cellWidth,
                top: 4,
                width: max(_cellWidth, 1),
                height: 56,
                child: Transform.translate(
                  offset: Offset(panelOffset, 0),
                  transformHitTests: false,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _beginPress(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select(widget.selectedIndex),
                      onTapCancel: _handleTapCancel,
                      onHorizontalDragStart: _handleDragStart,
                      onHorizontalDragUpdate: _handleDragUpdate,
                      onHorizontalDragEnd: _handleDragEnd,
                      onHorizontalDragCancel: _handleDragCancel,
                      child: Transform.scale(
                        key: const ValueKey('liquid-toggle-thumb-transform'),
                        scaleX: scaleX,
                        scaleY: scaleY,
                        transformHitTests: false,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: thumbRadius,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: AndroidGlassSurface(
                            blur: false,
                            liquidGlass: true,
                            liquidProgress: progress,
                            liquidAccentColor: Colors.transparent,
                            liquidBlurSigma: 8,
                            liquidRefractionHeight: 5,
                            liquidRefractionAmount: 10,
                            liquidChromaticAberration: 1,
                            liquidSize: Size(max(_cellWidth, 1), 56),
                            surfaceColor: thumbColor,
                            borderRadius: thumbRadius,
                            shape: const StadiumBorder(),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: thumbRadius,
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
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiquidNavigationItem extends StatelessWidget {
  final int index;
  final NavigationItem item;
  final bool selected;
  final double selectionProgress;
  final double pressProgress;
  final VoidCallback onPressed;

  const _LiquidNavigationItem({
    required this.index,
    required this.item,
    required this.selected,
    required this.selectionProgress,
    required this.pressProgress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      context.colorScheme.onSurfaceVariant,
      context.colorScheme.primary,
      selectionProgress,
    )!;
    final label = intl.Intl.message(item.label.name);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Center(
          child: Transform.scale(
            key: ValueKey('liquid-navigation-item-content-$index'),
            scale: 1 + 0.2 * pressProgress * selectionProgress,
            transformHitTests: false,
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
                    fontWeight: FontWeight.lerp(
                      FontWeight.w500,
                      FontWeight.w700,
                      selectionProgress,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
