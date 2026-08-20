// Adapted from AndroidLiquidGlass LiquidToggle.kt at commit b18eb0ff.
// Copyright AndroidLiquidGlass contributors. Licensed under Apache-2.0.
// Modified for Flutter and multi-destination navigation by FlClash contributors.

import 'dart:math';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/models/common.dart';
import 'package:flutter/gestures.dart';
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
  late final AnimationController _velocityController;
  late final AnimationController _highlightXController;
  late final Listenable _animation;
  late final SpringDescription _positionSpring;
  late final SpringDescription _pressSpring;
  late final SpringDescription _indicatorScaleXSpring;
  late final SpringDescription _indicatorScaleYSpring;
  late final SpringDescription _panelOffsetSpring;
  late final SpringDescription _velocitySpring;

  double _cellWidth = 0;
  int _committedIndex = 0;
  int? _deferredExternalIndex;
  int? _awaitingExternalIndex;
  int? _activePointer;
  Offset? _pointerStart;
  double _pointerStartLogical = 0;
  double _dragBasePosition = 0;
  bool _hasDragged = false;
  VelocityTracker? _velocityTracker;
  int _interactionEpoch = 0;

  @override
  void initState() {
    super.initState();
    _committedIndex = _clampIndex(widget.selectedIndex);
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
    _velocitySpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 300,
      ratio: 0.5,
    );
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: _committedIndex.toDouble(),
    );
    _pressController = AnimationController(vsync: this);
    _indicatorScaleXController = AnimationController.unbounded(
      vsync: this,
      value: 1,
    );
    _indicatorScaleYController = AnimationController.unbounded(
      vsync: this,
      value: 1,
    );
    _panelOffsetController = AnimationController.unbounded(vsync: this);
    _velocityController = AnimationController.unbounded(vsync: this);
    _highlightXController = AnimationController.unbounded(vsync: this);
    _animation = Listenable.merge(<Listenable>[
      _positionController,
      _pressController,
      _indicatorScaleXController,
      _indicatorScaleYController,
      _panelOffsetController,
      _velocityController,
      _highlightXController,
    ]);
  }

  @override
  void didUpdateWidget(covariant LiquidToggleNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedIndex = _clampIndex(widget.selectedIndex);
    if (_activePointer != null) {
      _deferredExternalIndex = selectedIndex;
      return;
    }
    if (_awaitingExternalIndex != null) {
      if (selectedIndex == _awaitingExternalIndex) {
        _awaitingExternalIndex = null;
        return;
      }
      if (selectedIndex != _committedIndex) {
        _awaitingExternalIndex = null;
      } else {
        return;
      }
    }
    if (selectedIndex == _committedIndex &&
        oldWidget.items.length == widget.items.length) {
      return;
    }
    _committedIndex = selectedIndex;
    _deferredExternalIndex = null;
    _animatePosition(selectedIndex.toDouble());
  }

  @override
  void dispose() {
    _positionController.dispose();
    _pressController.dispose();
    _indicatorScaleXController.dispose();
    _indicatorScaleYController.dispose();
    _panelOffsetController.dispose();
    _velocityController.dispose();
    _highlightXController.dispose();
    super.dispose();
  }

  int _clampIndex(int index) {
    if (widget.items.isEmpty) {
      return 0;
    }
    return index.clamp(0, widget.items.length - 1);
  }

  TickerFuture _springTo(
    AnimationController controller,
    SpringDescription spring,
    double target, {
    double velocity = 0,
  }) {
    return controller.animateWith(
      SpringSimulation(spring, controller.value, target, velocity),
    );
  }

  TickerFuture _animatePosition(double target, [double velocity = 0]) {
    _interactionEpoch++;
    return _springTo(
      _positionController,
      _positionSpring,
      target,
      velocity: velocity,
    );
  }

  void _beginPress() {
    _interactionEpoch++;
    _pressController.value = max(_pressController.value, 0.08);
    _springTo(_pressController, _pressSpring, 1);
    _springTo(_indicatorScaleXController, _indicatorScaleXSpring, 1.4);
    _springTo(_indicatorScaleYController, _indicatorScaleYSpring, 1.4);
  }

  void _releasePress() {
    _springTo(_pressController, _pressSpring, 0);
    _springTo(_indicatorScaleXController, _indicatorScaleXSpring, 1);
    _springTo(_indicatorScaleYController, _indicatorScaleYSpring, 1);
  }

  void _releasePressWhenSettled(TickerFuture positionAnimation) {
    final epoch = _interactionEpoch;
    positionAnimation.whenCompleteOrCancel(() {
      if (mounted && epoch == _interactionEpoch && _activePointer == null) {
        _releasePress();
      }
    });
  }

  void _settleSecondaryMotion() {
    _springTo(_panelOffsetController, _panelOffsetSpring, 0);
    _springTo(_velocityController, _velocitySpring, 0);
  }

  double _logicalPosition(double physicalX, TextDirection direction) {
    if (_cellWidth <= 0 || widget.items.isEmpty) {
      return _committedIndex.toDouble();
    }
    final physicalPosition = (physicalX - 4) / _cellWidth - 0.5;
    if (direction == TextDirection.ltr) {
      return physicalPosition;
    }
    return widget.items.length - 1 - physicalPosition;
  }

  double _directionFactor(TextDirection direction) {
    return direction == TextDirection.ltr ? 1 : -1;
  }

  double _rubberBand(double overtravel) {
    if (overtravel == 0) {
      return 0;
    }
    return 4 * overtravel / (24 + overtravel.abs());
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null || widget.items.isEmpty || _cellWidth <= 0) {
      return;
    }
    final direction = Directionality.of(context);
    final pointerLogical = _logicalPosition(event.localPosition.dx, direction);
    final target = _clampIndex(pointerLogical.round());
    _activePointer = event.pointer;
    _pointerStart = event.localPosition;
    _pointerStartLogical = pointerLogical;
    _dragBasePosition = target.toDouble();
    _hasDragged = false;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _highlightXController.value = event.localPosition.dx;
    _beginPress();
    _animatePosition(target.toDouble());
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _cellWidth <= 0) {
      return;
    }
    final direction = Directionality.of(context);
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _highlightXController.value = event.localPosition.dx;
    final currentLogical = _logicalPosition(event.localPosition.dx, direction);
    final rawPosition =
        _dragBasePosition + currentLogical - _pointerStartLogical;
    final maxPosition = max(widget.items.length - 1, 0).toDouble();
    final clampedPosition = rawPosition.clamp(0.0, maxPosition);
    final physicalOvertravel =
        (rawPosition - clampedPosition) *
        _cellWidth *
        _directionFactor(direction);
    _positionController
      ..stop()
      ..value = clampedPosition;
    _panelOffsetController
      ..stop()
      ..value = _rubberBand(physicalOvertravel);
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    _velocityController
      ..stop()
      ..value = (velocity / max(_cellWidth, 1) * _directionFactor(direction))
          .clamp(-12, 12);
    if (!_hasDragged &&
        (event.localPosition - (_pointerStart ?? event.localPosition))
                .distance >=
            6) {
      _hasDragged = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final direction = Directionality.of(context);
    final velocity =
        (_velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0) /
        max(_cellWidth, 1) *
        _directionFactor(direction);
    final projectedVelocity = velocity.clamp(-12.0, 12.0);
    final projection = (projectedVelocity * 0.035).clamp(-0.55, 0.55);
    final position = _hasDragged
        ? _positionController.value + projection
        : _dragBasePosition;
    final target = _clampIndex(position.round());
    _finishInteraction(target, velocity: projectedVelocity);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _activePointer = null;
    _pointerStart = null;
    _velocityTracker = null;
    _hasDragged = false;
    _awaitingExternalIndex = null;
    final deferredIndex = _deferredExternalIndex;
    _deferredExternalIndex = null;
    if (deferredIndex != null) {
      _committedIndex = deferredIndex;
    }
    final positionAnimation = _animatePosition(_committedIndex.toDouble());
    _settleSecondaryMotion();
    _releasePressWhenSettled(positionAnimation);
  }

  void _finishInteraction(int target, {required double velocity}) {
    _activePointer = null;
    _pointerStart = null;
    _velocityTracker = null;
    _hasDragged = false;
    _deferredExternalIndex = null;
    final changed = target != _committedIndex;
    _committedIndex = target;
    _awaitingExternalIndex = changed ? target : null;
    final positionAnimation = _animatePosition(target.toDouble(), velocity);
    _settleSecondaryMotion();
    if (changed) {
      widget.onSelected(target);
    }
    _releasePressWhenSettled(positionAnimation);
  }

  void _selectFromSemantics(int index) {
    if (_activePointer != null) {
      return;
    }
    _beginPress();
    _finishInteraction(_clampIndex(index), velocity: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final panelColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.34);
    final indicatorColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.22);
    final panelRadius = BorderRadius.circular(32);
    final indicatorRadius = BorderRadius.circular(28);
    return SizedBox(
      key: const ValueKey('liquid-toggle-navigation'),
      height: AndroidAppearanceTokens.liquidNavigationBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _cellWidth = (constraints.maxWidth - 8) / widget.items.length;
          return AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final maxPosition = max(widget.items.length - 1, 0).toDouble();
              final position = _positionController.value.clamp(
                0.0,
                maxPosition,
              );
              final pressProgress = _pressController.value.clamp(0.0, 1.0);
              final panelScale =
                  1 + 16 / max(constraints.maxWidth, 1) * pressProgress;
              final panelOffset = _panelOffsetController.value;
              final logicalVelocity = _velocityController.value.clamp(
                -12.0,
                12.0,
              );
              final velocityMagnitude = logicalVelocity.abs() / 12;
              final scaleX =
                  _indicatorScaleXController.value *
                  (1 + pressProgress * 0.18 + velocityMagnitude * 0.12);
              final scaleY =
                  _indicatorScaleYController.value *
                  (1 + pressProgress * 0.12 - velocityMagnitude * 0.06);
              final directionFactor = _directionFactor(
                Directionality.of(context),
              );
              final velocityOffset = logicalVelocity * 0.45 * directionFactor;
              final indicatorStart = 4 + position * _cellWidth;
              final highlightLocalX =
                  (_highlightXController.value - indicatorStart) /
                  max(_cellWidth, 1);
              final highlightAlignment = Alignment(
                (highlightLocalX * 2 - 1).clamp(-1.0, 1.0),
                -0.25,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _beginPress(),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        key: const ValueKey('liquid-glass-panel-layer'),
                        child: Transform.translate(
                          key: const ValueKey('liquid-toggle-panel-offset'),
                          offset: Offset(panelOffset * 0.55, 0),
                          transformHitTests: false,
                          child: Transform.scale(
                            key: const ValueKey(
                              'liquid-toggle-panel-transform',
                            ),
                            scale: panelScale,
                            transformHitTests: false,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: panelRadius,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.2 : 0.1,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: -2,
                                    offset: const Offset(0, 7),
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
                                liquidDepthEffect: 0.12,
                                scaleLiquidBlurWithProgress: false,
                                surfaceColor: panelColor,
                                borderRadius: panelRadius,
                                shape: const StadiumBorder(),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        key: const ValueKey('liquid-glass-indicator-layer'),
                        start: indicatorStart,
                        top: 4,
                        width: max(_cellWidth, 1),
                        height: 56,
                        child: Transform.translate(
                          key: const ValueKey('liquid-toggle-indicator-offset'),
                          offset: Offset(panelOffset + velocityOffset, 0),
                          transformHitTests: false,
                          child: Transform(
                            key: const ValueKey(
                              'liquid-toggle-thumb-transform',
                            ),
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(
                              scaleX,
                              scaleY,
                              1,
                            )..setEntry(0, 1, logicalVelocity / 240),
                            transformHitTests: false,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: indicatorRadius,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha:
                                          (isDark ? 0.16 : 0.08) +
                                          pressProgress * 0.04,
                                    ),
                                    blurRadius: 12,
                                    spreadRadius: -2,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: AndroidGlassSurface(
                                blur: false,
                                liquidGlass: true,
                                liquidProgress: 0.35 + pressProgress * 0.65,
                                liquidAccentColor: Colors.transparent,
                                liquidBlurSigma: 4,
                                liquidRefractionHeight: 5 + pressProgress * 5,
                                liquidRefractionAmount: 8 + pressProgress * 6,
                                liquidChromaticAberration:
                                    0.1 + pressProgress * 0.4,
                                liquidDepthEffect: 0.18 + pressProgress * 0.2,
                                scaleLiquidBlurWithProgress: false,
                                surfaceColor: indicatorColor,
                                borderRadius: indicatorRadius,
                                shape: const StadiumBorder(),
                                child: DecoratedBox(
                                  key: const ValueKey(
                                    'liquid-glass-interactive-highlight',
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: indicatorRadius,
                                    gradient: RadialGradient(
                                      center: highlightAlignment,
                                      radius: 1.15,
                                      colors: <Color>[
                                        Colors.white.withValues(
                                          alpha: 0.04 + pressProgress * 0.18,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        key: const ValueKey('liquid-glass-content-layer'),
                        child: Transform.translate(
                          offset: Offset(panelOffset * 0.55, 0),
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
                                    key: ValueKey(
                                      'liquid-navigation-item-$index',
                                    ),
                                    child: _LiquidNavigationItem(
                                      index: index,
                                      item: widget.items[index],
                                      selected: index == _committedIndex,
                                      selectionProgress:
                                          (1 - (position - index).abs()).clamp(
                                            0,
                                            1,
                                          ),
                                      pressProgress: pressProgress,
                                      onPressed: () =>
                                          _selectFromSemantics(index),
                                      onPointerDown: _handlePointerDown,
                                      onPressDown: _beginPress,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
  final void Function(PointerDownEvent) onPointerDown;
  final VoidCallback onPressDown;

  const _LiquidNavigationItem({
    required this.index,
    required this.item,
    required this.selected,
    required this.selectionProgress,
    required this.pressProgress,
    required this.onPressed,
    required this.onPointerDown,
    required this.onPressDown,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      context.colorScheme.onSurfaceVariant,
      context.colorScheme.onSurface,
      selectionProgress,
    )!;
    final label = intl.Intl.message(item.label.name);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPressDown(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: onPointerDown,
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
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
      ),
    );
  }
}
