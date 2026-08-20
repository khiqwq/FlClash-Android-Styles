// Adapted from AndroidLiquidGlass LiquidToggle.kt at commit b18eb0ff.
// Copyright AndroidLiquidGlass contributors. Licensed under Apache-2.0.
// Modified for Flutter and multi-destination navigation by FlClash contributors.

import 'dart:async';
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
  static const double _pressedScale = 78 / 56;

  late final AnimationController _positionController;
  late final AnimationController _pressController;
  late final AnimationController _indicatorScaleXController;
  late final AnimationController _indicatorScaleYController;
  late final AnimationController _panelOffsetController;
  late final AnimationController _velocityController;
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
    _animation = Listenable.merge(<Listenable>[
      _positionController,
      _pressController,
      _indicatorScaleXController,
      _indicatorScaleYController,
      _panelOffsetController,
      _velocityController,
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
      if (oldWidget.items.length == widget.items.length) {
        return;
      }
      _awaitingExternalIndex = null;
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
    _springTo(
      _indicatorScaleXController,
      _indicatorScaleXSpring,
      _pressedScale,
    );
    _springTo(
      _indicatorScaleYController,
      _indicatorScaleYSpring,
      _pressedScale,
    );
  }

  void _releasePress() {
    _springTo(_pressController, _pressSpring, 0);
    _springTo(_indicatorScaleXController, _indicatorScaleXSpring, 1);
    _springTo(_indicatorScaleYController, _indicatorScaleYSpring, 1);
  }

  void _scheduleRelease(double target) {
    final epoch = _interactionEpoch;
    unawaited(_releasePressNearTarget(target, epoch));
  }

  Future<void> _releasePressNearTarget(double target, int epoch) async {
    await WidgetsBinding.instance.endOfFrame;
    final valueRange = max(widget.items.length - 1, 1).toDouble();
    final threshold = valueRange * 0.025;
    while (mounted &&
        epoch == _interactionEpoch &&
        _activePointer == null &&
        (_positionController.value - target).abs() >= threshold) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted && epoch == _interactionEpoch && _activePointer == null) {
      _releasePress();
    }
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
    _beginPress();
    _animatePosition(target.toDouble());
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _cellWidth <= 0) {
      return;
    }
    final direction = Directionality.of(context);
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final currentLogical = _logicalPosition(event.localPosition.dx, direction);
    final rawPosition =
        _dragBasePosition + currentLogical - _pointerStartLogical;
    final maxPosition = max(widget.items.length - 1, 0).toDouble();
    final clampedPosition = rawPosition.clamp(0.0, maxPosition);
    _positionController
      ..stop()
      ..value = clampedPosition;
    _panelOffsetController
      ..stop()
      ..value += event.delta.dx;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    final valueRange = max(widget.items.length - 1, 1);
    _velocityController
      ..stop()
      ..value =
          (velocity /
                  max(_cellWidth, 1) /
                  valueRange *
                  _directionFactor(direction))
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
    final position = _hasDragged
        ? _positionController.value
        : _dragBasePosition;
    final target = _clampIndex(position.round());
    _finishInteraction(target, velocity: 0);
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
    final target = _committedIndex.toDouble();
    _animatePosition(target);
    _settleSecondaryMotion();
    _scheduleRelease(target);
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
    final targetValue = target.toDouble();
    _animatePosition(targetValue, velocity);
    _settleSecondaryMotion();
    if (changed) {
      widget.onSelected(target);
    }
    _scheduleRelease(targetValue);
  }

  void _activateItem(int index) {
    final target = _clampIndex(index);
    if (_activePointer != null) {
      if (_hasDragged) {
        return;
      }
      _activePointer = null;
      _pointerStart = null;
      _velocityTracker = null;
      _hasDragged = false;
      _deferredExternalIndex = null;
      _finishInteraction(target, velocity: 0);
      return;
    }
    if (_committedIndex == target) {
      return;
    }
    _beginPress();
    _finishInteraction(target, velocity: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xFF242424).withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.4);
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
              final panelFraction =
                  (_panelOffsetController.value / max(constraints.maxWidth, 1))
                      .clamp(-1.0, 1.0);
              final panelOffset =
                  4 *
                  panelFraction.sign *
                  Curves.easeOut.transform(panelFraction.abs());
              final logicalVelocity = _velocityController.value.clamp(
                -12.0,
                12.0,
              );
              final velocity = logicalVelocity / 10;
              final scaleX =
                  _indicatorScaleXController.value /
                  (1 - (velocity * 0.75).clamp(-0.2, 0.2));
              final scaleY =
                  _indicatorScaleYController.value *
                  (1 - (velocity * 0.25).clamp(-0.2, 0.2));
              final indicatorStart = 4 + position * _cellWidth;
              final direction = Directionality.of(context);
              final physicalIndicatorCenter = switch (direction) {
                TextDirection.ltr =>
                  4 + (position + 0.5) * _cellWidth + panelOffset,
                TextDirection.rtl =>
                  constraints.maxWidth -
                      4 -
                      (position + 0.5) * _cellWidth +
                      panelOffset,
              };
              const highlightAlignment = Alignment(0, -0.25);
              final panelHighlightAlignment = Alignment(
                (physicalIndicatorCenter / max(constraints.maxWidth, 1) * 2 - 1)
                    .clamp(-1.0, 1.0),
                -0.25,
              );
              final indicatorColor = Color.lerp(
                isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.03),
                pressProgress,
              )!;
              final contentLayer = Positioned.fill(
                key: const ValueKey('liquid-glass-content-layer'),
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
                              selected: index == _committedIndex,
                              onPressed: () => _activateItem(index),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
              return Listener(
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
                        offset: Offset(panelOffset, 0),
                        transformHitTests: false,
                        child: Transform.scale(
                          key: const ValueKey('liquid-toggle-panel-transform'),
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
                                  blurRadius: 10,
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
                              child: DecoratedBox(
                                key: const ValueKey(
                                  'liquid-glass-panel-highlight',
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: panelRadius,
                                  gradient: RadialGradient(
                                    center: panelHighlightAlignment,
                                    radius: 1.5,
                                    colors: <Color>[
                                      Colors.white.withValues(
                                        alpha: 0.08 * pressProgress,
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
                    contentLayer,
                    PositionedDirectional(
                      key: const ValueKey('liquid-glass-indicator-layer'),
                      start: indicatorStart,
                      top: 4,
                      width: max(_cellWidth, 1),
                      height: 56,
                      child: IgnorePointer(
                        child: Transform.translate(
                          key: const ValueKey('liquid-toggle-indicator-offset'),
                          offset: Offset(panelOffset, 0),
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
                            ),
                            transformHitTests: false,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: indicatorRadius,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: 0.1 * pressProgress,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: AndroidGlassSurface(
                                blur: false,
                                liquidGlass: true,
                                liquidProgress: pressProgress,
                                liquidAccentColor: Colors.transparent,
                                liquidBlurSigma: 0,
                                liquidRefractionHeight: 10 * pressProgress,
                                liquidRefractionAmount: 14 * pressProgress,
                                liquidChromaticAberration: 0.5,
                                liquidDepthEffect: pressProgress,
                                scaleLiquidBlurWithProgress: false,
                                surfaceColor: indicatorColor,
                                borderRadius: indicatorRadius,
                                shape: const StadiumBorder(),
                                child: Stack(
                                  key: const ValueKey(
                                    'liquid-glass-accent-content-layer',
                                  ),
                                  fit: StackFit.expand,
                                  children: [
                                    DecoratedBox(
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
                                              alpha:
                                                  0.04 + pressProgress * 0.18,
                                            ),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    for (
                                      var index = 0;
                                      index < widget.items.length;
                                      index++
                                    )
                                      IgnorePointer(
                                        child: Opacity(
                                          opacity:
                                              (1 - (position - index).abs())
                                                  .clamp(0, 1),
                                          child: _LiquidIndicatorContent(
                                            index: index,
                                            item: widget.items[index],
                                            color: context.colorScheme.primary,
                                            scale: 1 + 0.2 * pressProgress,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
  final VoidCallback onPressed;

  const _LiquidNavigationItem({
    required this.index,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = miuixOnSurfaceContainer(Theme.brightnessOf(context));
    final color = surfaceColor.withValues(
      alpha: selected ? surfaceColor.a : surfaceColor.a * 0.4,
    );
    final label = intl.Intl.message(item.label.name);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      onTap: onPressed,
      child: Center(
        child: Transform.scale(
          key: ValueKey('liquid-navigation-item-content-$index'),
          scale: 1,
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
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidIndicatorContent extends StatelessWidget {
  final int index;
  final NavigationItem item;
  final Color color;
  final double scale;

  const _LiquidIndicatorContent({
    required this.index,
    required this.item,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.scale(
        key: ValueKey('liquid-indicator-content-transform-$index'),
        scale: scale,
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
              intl.Intl.message(item.label.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
