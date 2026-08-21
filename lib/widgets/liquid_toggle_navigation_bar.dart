// Adapted from AndroidLiquidGlass LiquidToggle.kt at commit b18eb0ff.
// Copyright 2025 Kyant. Licensed under Apache-2.0.
// Modified for Flutter and multi-destination navigation by FlClash contributors.

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

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
  static const double _visibilityThreshold = 0.001;
  static const double _pressedScale = 1.5;
  static const double _dragWidth = 20;
  static const double _trackPadding = 2;

  late final AnimationController _positionController;
  late final AnimationController _velocityController;
  late final AnimationController _pressController;
  late final AnimationController _scaleXController;
  late final AnimationController _scaleYController;
  late final Listenable _animation;
  late final SpringDescription _valueSpring;
  late final SpringDescription _velocitySpring;
  late final SpringDescription _pressSpring;
  late final SpringDescription _scaleXSpring;
  late final SpringDescription _scaleYSpring;

  final Stopwatch _velocityClock = Stopwatch();

  double _cellWidth = 0;
  double _fraction = 0;
  double _positionTarget = 0;
  double _lastVelocityValue = 0;
  Duration _lastVelocityTime = Duration.zero;
  int _committedIndex = 0;
  int? _deferredExternalIndex;
  int? _awaitingExternalIndex;
  int? _awaitingExternalBaselineIndex;
  Duration _awaitingExternalStartedAt = Duration.zero;
  final Map<int, List<Duration>> _supersededExternalTimes = {};
  Timer? _supersededExternalFallbackTimer;
  int? _activePointer;
  int? _directTapIndex;
  bool _didDrag = false;
  bool _pointerGestureRejected = false;
  bool _activeIsIndicator = false;
  bool _tracksValueVelocity = false;
  Offset _pointerDisplacement = Offset.zero;
  double _pointerSlop = 0;
  double _pointerStartFraction = 0;
  int _releaseEpoch = 0;

  @override
  void initState() {
    super.initState();
    _committedIndex = _clampIndex(widget.selectedIndex);
    _fraction = _committedIndex.toDouble();
    _positionTarget = _fraction;
    _valueSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 1000,
      ratio: 1,
    );
    _velocitySpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 300,
      ratio: 0.5,
    );
    _pressSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 1000,
      ratio: 1,
    );
    _scaleXSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 250,
      ratio: 0.6,
    );
    _scaleYSpring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 250,
      ratio: 0.7,
    );
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: _fraction,
    )..addListener(_updateVelocity);
    _velocityController = AnimationController.unbounded(vsync: this);
    _pressController = AnimationController(vsync: this);
    _scaleXController = AnimationController.unbounded(vsync: this, value: 1);
    _scaleYController = AnimationController.unbounded(vsync: this, value: 1);
    _animation = Listenable.merge(<Listenable>[
      _positionController,
      _velocityController,
      _pressController,
      _scaleXController,
      _scaleYController,
    ]);
  }

  @override
  void didUpdateWidget(covariant LiquidToggleNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    var selectedIndex = _clampIndex(widget.selectedIndex);
    final awaitingExternalIndex = _awaitingExternalIndex;
    if (oldWidget.items.length != widget.items.length &&
        awaitingExternalIndex != null &&
        widget.selectedIndex == awaitingExternalIndex &&
        !_isItemIndex(widget.selectedIndex)) {
      selectedIndex = _clampIndex(oldWidget.selectedIndex);
    }
    if (!_canPreserveSelectionState(oldWidget)) {
      _reconcileSelection(
        selectedIndex,
        markAwaitingSuperseded:
            !(oldWidget.items.length != widget.items.length &&
                awaitingExternalIndex != null &&
                widget.selectedIndex == awaitingExternalIndex &&
                !_isItemIndex(widget.selectedIndex)),
      );
      return;
    }
    if (widget.selectedIndex != _awaitingExternalIndex &&
        _consumeSupersededExternalIndex(widget.selectedIndex)) {
      final awaitingExternalIndex = _awaitingExternalIndex;
      if (awaitingExternalIndex != null &&
          awaitingExternalIndex != _awaitingExternalBaselineIndex) {
        final elapsed =
            WidgetsBinding.instance.currentSystemFrameTimeStamp -
            _awaitingExternalStartedAt;
        if (elapsed >= const Duration(milliseconds: 24)) {
          _applyExternalSelection(widget.selectedIndex);
        } else {
          _scheduleSupersededExternalFallback(
            widget.selectedIndex,
            awaitingExternalIndex,
          );
        }
      }
      return;
    }
    if (_activePointer != null) {
      if (_awaitingExternalIndex != null) {
        if (selectedIndex == _awaitingExternalIndex) {
          _clearAwaitingExternalIndex();
          return;
        }
        if (selectedIndex == _clampIndex(oldWidget.selectedIndex)) {
          return;
        }
      }
      _deferredExternalIndex = selectedIndex == _committedIndex
          ? null
          : selectedIndex;
      return;
    }
    if (_awaitingExternalIndex != null) {
      if (selectedIndex == _awaitingExternalIndex) {
        _clearAwaitingExternalIndex();
        return;
      }
      if (selectedIndex == _clampIndex(oldWidget.selectedIndex)) {
        return;
      }
      _clearAwaitingExternalIndex();
    }
    if (selectedIndex == _committedIndex &&
        oldWidget.items.length == widget.items.length) {
      return;
    }
    _committedIndex = selectedIndex;
    _deferredExternalIndex = null;
    _fraction = selectedIndex.toDouble();
    _animateToValue(_fraction);
  }

  @override
  void dispose() {
    _releaseEpoch++;
    _supersededExternalFallbackTimer?.cancel();
    _clearPointerInteraction();
    _stopVelocityTracking();
    _positionController
      ..removeListener(_updateVelocity)
      ..dispose();
    _velocityController.dispose();
    _pressController.dispose();
    _scaleXController.dispose();
    _scaleYController.dispose();
    super.dispose();
  }

  double get _valueRange => max(widget.items.length - 1, 1).toDouble();

  bool _canPreserveSelectionState(LiquidToggleNavigationBar oldWidget) {
    if (oldWidget.items.length != widget.items.length) {
      return false;
    }
    final itemCount = widget.items.length;
    bool isValidIndex(int? index) {
      if (index == null) {
        return true;
      }
      if (itemCount == 0) {
        return index == 0;
      }
      return index >= 0 && index < itemCount;
    }

    if (!isValidIndex(_committedIndex) ||
        !isValidIndex(_awaitingExternalIndex) ||
        !isValidIndex(_deferredExternalIndex) ||
        !isValidIndex(_directTapIndex)) {
      return false;
    }
    return (_activePointer == null) == (_directTapIndex == null);
  }

  void _markSupersededExternalIndex(int index) {
    final now = WidgetsBinding.instance.currentSystemFrameTimeStamp;
    _supersededExternalTimes.update(
      index,
      (times) => [...times, now],
      ifAbsent: () => [now],
    );
  }

  bool _consumeSupersededExternalIndex(int index) {
    final times = _supersededExternalTimes[index];
    if (times == null) {
      return false;
    }
    final now = WidgetsBinding.instance.currentSystemFrameTimeStamp;
    final activeTimes = times
        .where((time) => now - time <= const Duration(milliseconds: 250))
        .toList();
    if (activeTimes.isEmpty) {
      _supersededExternalTimes.remove(index);
      return false;
    }
    activeTimes.removeAt(0);
    if (activeTimes.isEmpty) {
      _supersededExternalTimes.remove(index);
    } else {
      _supersededExternalTimes[index] = activeTimes;
    }
    return true;
  }

  void _scheduleSupersededExternalFallback(
    int index,
    int awaitingExternalIndex,
  ) {
    _supersededExternalFallbackTimer?.cancel();
    _supersededExternalFallbackTimer = Timer(
      const Duration(milliseconds: 16),
      () {
        if (!mounted ||
            widget.selectedIndex != index ||
            _awaitingExternalIndex != awaitingExternalIndex) {
          return;
        }
        _applyExternalSelection(index);
      },
    );
  }

  void _setAwaitingExternalIndex(int index) {
    _supersededExternalFallbackTimer?.cancel();
    final previousIndex = _awaitingExternalIndex;
    if (previousIndex != null && previousIndex != index) {
      _markSupersededExternalIndex(previousIndex);
    }
    _awaitingExternalIndex = index;
    _awaitingExternalBaselineIndex = widget.selectedIndex;
    _awaitingExternalStartedAt =
        WidgetsBinding.instance.currentSystemFrameTimeStamp;
  }

  void _clearAwaitingExternalIndex() {
    _supersededExternalFallbackTimer?.cancel();
    _awaitingExternalIndex = null;
    _awaitingExternalBaselineIndex = null;
    _awaitingExternalStartedAt = Duration.zero;
  }

  void _reconcileSelection(
    int selectedIndex, {
    bool markAwaitingSuperseded = true,
  }) {
    final awaitingExternalIndex = _awaitingExternalIndex;
    if (markAwaitingSuperseded &&
        awaitingExternalIndex != null &&
        awaitingExternalIndex != selectedIndex) {
      _markSupersededExternalIndex(awaitingExternalIndex);
    }
    _releaseEpoch++;
    _clearPointerInteraction();
    _stopVelocityTracking();
    _releasePress();
    _committedIndex = selectedIndex;
    _awaitingExternalIndex = null;
    _awaitingExternalBaselineIndex = null;
    _awaitingExternalStartedAt = Duration.zero;
    _supersededExternalFallbackTimer?.cancel();
    _deferredExternalIndex = null;
    _fraction = selectedIndex.toDouble();
    _animateToValue(_fraction);
  }

  bool _isItemIndex(int index) {
    return index >= 0 && index < widget.items.length;
  }

  int _clampIndex(int index) {
    if (widget.items.isEmpty) {
      return 0;
    }
    return index.clamp(0, widget.items.length - 1);
  }

  double _clampValue(double value) {
    return value.clamp(0, max(widget.items.length - 1, 0).toDouble());
  }

  TickerFuture _springTo(
    AnimationController controller,
    SpringDescription spring,
    double target,
    double threshold, {
    double velocity = 0,
  }) {
    final simulation = SpringSimulation(
      spring,
      controller.value,
      target,
      velocity,
    )..tolerance = Tolerance(distance: threshold, velocity: threshold);
    return controller.animateWith(simulation);
  }

  void _startVelocityTracking() {
    if (_tracksValueVelocity) {
      return;
    }
    _tracksValueVelocity = true;
    _velocityClock
      ..reset()
      ..start();
    _lastVelocityTime = Duration.zero;
    _lastVelocityValue = _positionController.value;
  }

  void _stopVelocityTracking() {
    _tracksValueVelocity = false;
    _velocityClock.stop();
  }

  void _updateVelocity() {
    if (!_tracksValueVelocity) {
      return;
    }

    final now = _velocityClock.elapsed;
    final elapsed =
        (now - _lastVelocityTime).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (elapsed <= 0) {
      return;
    }
    final value = _positionController.value;
    final targetVelocity = (value - _lastVelocityValue) / elapsed / _valueRange;
    _lastVelocityValue = value;
    _lastVelocityTime = now;
    _springTo(
      _velocityController,
      _velocitySpring,
      targetVelocity,
      _visibilityThreshold * 10,
    );
  }

  TickerFuture _animatePosition(double target, {required bool trackVelocity}) {
    _positionTarget = _clampValue(target);
    if (trackVelocity) {
      _startVelocityTracking();
    } else {
      _stopVelocityTracking();
    }
    return _springTo(
      _positionController,
      _valueSpring,
      _positionTarget,
      _visibilityThreshold,
    );
  }

  void _updateValue(double value) {
    _fraction = _clampValue(value);
    _animatePosition(_fraction, trackVelocity: true);
  }

  void _animateToValue(double value) {
    _beginPress();
    _fraction = _clampValue(value);
    _animatePosition(_fraction, trackVelocity: false);
    if (_velocityController.value != 0) {
      _springTo(
        _velocityController,
        _velocitySpring,
        0,
        _visibilityThreshold * 10,
      );
    }
    _scheduleRelease();
  }

  void _beginPress() {
    _releaseEpoch++;
    _springTo(_pressController, _pressSpring, 1, _visibilityThreshold);
    _springTo(
      _scaleXController,
      _scaleXSpring,
      _pressedScale,
      _visibilityThreshold,
    );
    _springTo(
      _scaleYController,
      _scaleYSpring,
      _pressedScale,
      _visibilityThreshold,
    );
  }

  void _releasePress() {
    _springTo(_pressController, _pressSpring, 0, _visibilityThreshold);
    _springTo(_scaleXController, _scaleXSpring, 1, _visibilityThreshold);
    _springTo(_scaleYController, _scaleYSpring, 1, _visibilityThreshold);
  }

  void _scheduleRelease() {
    final epoch = ++_releaseEpoch;
    unawaited(_releaseNearTarget(epoch));
  }

  Future<void> _releaseNearTarget(int epoch) async {
    await WidgetsBinding.instance.endOfFrame;
    final threshold = _valueRange * 0.025;
    while (mounted && epoch == _releaseEpoch) {
      if (_activePointer == null &&
          (_positionController.value - _positionTarget).abs() < threshold) {
        _releasePress();
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Rect _visibleIndicatorRect() {
    final size = context.size;
    if (size == null || _cellWidth <= 0) {
      return Rect.zero;
    }
    final maxPosition = max(widget.items.length - 1, 0).toDouble();
    final position = _positionController.value.clamp(0.0, maxPosition);
    final velocity = _velocityController.value / 50;
    final scaleX =
        _scaleXController.value / (1 - (velocity * 0.75).clamp(-0.2, 0.2));
    final scaleY =
        _scaleYController.value * (1 - (velocity * 0.25).clamp(-0.2, 0.2));
    final start = _trackPadding + position * _cellWidth;
    final direction = Directionality.of(context);
    final left = direction == TextDirection.ltr
        ? start
        : size.width - start - _cellWidth;
    final height = size.height - _trackPadding * 2;
    final width = _cellWidth * scaleX.abs();
    final scaledHeight = height * scaleY.abs();
    return Rect.fromLTWH(
      left + (_cellWidth - width) / 2,
      _trackPadding + (height - scaledHeight) / 2,
      width,
      scaledHeight,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null || widget.items.isEmpty) {
      return;
    }
    final direction = Directionality.of(context);
    final physicalPosition =
        (event.localPosition.dx - _trackPadding) / _cellWidth - 0.5;
    final logicalPosition = direction == TextDirection.ltr
        ? physicalPosition
        : widget.items.length - 1 - physicalPosition;
    final target = _clampIndex(logicalPosition.round());
    _activePointer = event.pointer;
    _directTapIndex = target;
    _didDrag = false;
    _pointerGestureRejected = false;
    _pointerDisplacement = Offset.zero;
    _pointerSlop = computeHitSlop(
      event.kind,
      MediaQuery.gestureSettingsOf(context),
    );
    _pointerStartFraction = _fraction;
    _activeIsIndicator = _visibleIndicatorRect().contains(event.localPosition);
    if (!_activeIsIndicator) {
      return;
    }
    _stopVelocityTracking();
    _beginPress();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _pointerDisplacement += event.delta;
    final horizontalDistance = _pointerDisplacement.dx.abs();
    final verticalDistance = _pointerDisplacement.dy.abs();
    if (!_activeIsIndicator) {
      if (horizontalDistance > _pointerSlop ||
          verticalDistance > _pointerSlop) {
        _pointerGestureRejected = true;
      }
      return;
    }
    if (_pointerGestureRejected) {
      return;
    }
    if (!_didDrag) {
      if (horizontalDistance <= _pointerSlop &&
          verticalDistance <= _pointerSlop) {
        return;
      }
      if (horizontalDistance <= _pointerSlop ||
          horizontalDistance <= verticalDistance) {
        _pointerGestureRejected = true;
        return;
      }
      _didDrag = true;
    }
    final direction = Directionality.of(context);
    final delta =
        _pointerDisplacement.dx /
        _dragWidth *
        (direction == TextDirection.ltr ? 1 : -1);
    _updateValue(_pointerStartFraction + delta);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _finishIndicatorInteraction(canceled: false);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _finishIndicatorInteraction(canceled: true);
  }

  void _clearPointerInteraction() {
    _activePointer = null;
    _directTapIndex = null;
    _activeIsIndicator = false;
    _didDrag = false;
    _pointerGestureRejected = false;
    _pointerDisplacement = Offset.zero;
    _pointerSlop = 0;
    _pointerStartFraction = 0;
  }

  void _finishIndicatorInteraction({required bool canceled}) {
    final activeIsIndicator = _activeIsIndicator;
    final directTapIndex = _directTapIndex;
    final pointerGestureRejected = _pointerGestureRejected;
    final didDrag = _didDrag;
    _clearPointerInteraction();
    if (!activeIsIndicator) {
      final deferredIndex = _deferredExternalIndex;
      _deferredExternalIndex = null;
      if (canceled) {
        if (deferredIndex != null) {
          _applyExternalSelection(deferredIndex);
        } else {
          _scheduleRelease();
        }
        return;
      }
      if (deferredIndex != null && directTapIndex == _committedIndex) {
        _applyExternalSelection(deferredIndex);
        return;
      }
      if (!didDrag && !pointerGestureRejected && directTapIndex != null) {
        _activateItem(directTapIndex);
        return;
      }
      if (deferredIndex != null) {
        _applyExternalSelection(deferredIndex);
      } else {
        _scheduleRelease();
      }
      return;
    }
    final deferredIndex = _deferredExternalIndex;
    _deferredExternalIndex = null;
    if (!didDrag && deferredIndex != null) {
      _committedIndex = deferredIndex;
      _clearAwaitingExternalIndex();
      _fraction = deferredIndex.toDouble();
      _animatePosition(_fraction, trackVelocity: false);
      _scheduleRelease();
      return;
    }
    if (!canceled &&
        !pointerGestureRejected &&
        !didDrag &&
        directTapIndex != null &&
        directTapIndex != _committedIndex) {
      _activateItem(directTapIndex);
      return;
    }
    final target = didDrag ? _clampIndex(_fraction.round()) : _committedIndex;
    final changed = target != _committedIndex;
    _committedIndex = target;
    if (changed) {
      _setAwaitingExternalIndex(target);
    }
    _fraction = target.toDouble();
    if (didDrag) {
      _updateValue(_fraction);
    } else {
      _animatePosition(_fraction, trackVelocity: false);
    }
    _scheduleRelease();
    if (changed) {
      widget.onSelected(target);
    }
  }

  void _applyExternalSelection(int index) {
    final target = _clampIndex(index);
    _committedIndex = target;
    _clearAwaitingExternalIndex();
    _fraction = target.toDouble();
    _animateToValue(_fraction);
  }

  void _activateItem(int index) {
    if (_activePointer != null) {
      return;
    }
    final target = _clampIndex(index);
    final changed = target != _committedIndex;
    _committedIndex = target;
    if (changed) {
      _setAwaitingExternalIndex(target);
    }
    _fraction = target.toDouble();
    _animateToValue(_fraction);
    if (changed) {
      widget.onSelected(target);
    }
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
    return SizedBox(
      key: const ValueKey('liquid-toggle-navigation'),
      width: double.infinity,
      height: AndroidAppearanceTokens.liquidNavigationBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _cellWidth =
              (constraints.maxWidth - _trackPadding * 2) / widget.items.length;
          return AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final committedIndex = _clampIndex(_committedIndex);
              final maxPosition = max(widget.items.length - 1, 0).toDouble();
              final position = _positionController.value.clamp(
                0.0,
                maxPosition,
              );
              final progress = _pressController.value.clamp(0.0, 1.0);
              final selectedLabelColor = isDark
                  ? context.colorScheme.onSurface
                  : Colors.black;
              final selectedIconColor = Color.lerp(
                context.colorScheme.primary,
                selectedLabelColor,
                progress,
              )!;
              final velocity = _velocityController.value / 50;
              final scaleX =
                  _scaleXController.value /
                  (1 - (velocity * 0.75).clamp(-0.2, 0.2));
              final scaleY =
                  _scaleYController.value *
                  (1 - (velocity * 0.25).clamp(-0.2, 0.2));
              final trackScaleX = ui.lerpDouble(2 / 3, 0.75, progress)!;
              final trackScaleY = ui.lerpDouble(0, 0.75, progress)!;
              final indicatorStart = _trackPadding + position * _cellWidth;
              final indicatorHeight = constraints.maxHeight - _trackPadding * 2;
              final direction = Directionality.of(context);
              final indicatorLeft = direction == TextDirection.ltr
                  ? indicatorStart
                  : constraints.maxWidth - indicatorStart - _cellWidth;
              final visibleWidth = _cellWidth * scaleX.abs();
              final visibleHeight = indicatorHeight * scaleY.abs();
              final indicatorExclusion = Rect.fromLTWH(
                indicatorLeft + (_cellWidth - visibleWidth) / 2,
                _trackPadding + (indicatorHeight - visibleHeight) / 2,
                visibleWidth,
                visibleHeight,
              );
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                child: Stack(
                  alignment: AlignmentDirectional.centerStart,
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    PositionedDirectional(
                      key: const ValueKey('liquid-glass-indicator-layer'),
                      start: indicatorStart,
                      top: _trackPadding,
                      width: max(_cellWidth, 1),
                      height: max(indicatorHeight, 1),
                      child: Transform(
                        key: const ValueKey('liquid-toggle-thumb-transform'),
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                        transformHitTests: false,
                        child: CustomPaint(
                          child: AndroidGlassSurface(
                            key: const ValueKey('liquid-indicator-surface'),
                            blur: false,
                            liquidGlass: true,
                            liquidProgress: progress,
                            liquidAccentColor: Colors.transparent,
                            liquidBlurSigma: 8 * (1 - progress),
                            liquidRefractionHeight: 5 * progress,
                            liquidRefractionAmount: 10 * progress,
                            liquidChromaticAberration: 1,
                            liquidDepthEffect: 0,
                            liquidSamplePadding: 0,
                            scaleLiquidBlurWithProgress: false,
                            showLiquidRim: false,
                            surfaceColor:
                                (isDark
                                        ? context.colorScheme.surfaceContainer
                                        : Colors.white)
                                    .withValues(alpha: 1 - progress),
                            borderRadius: BorderRadius.circular(
                              indicatorHeight / 2,
                            ),
                            shape: const StadiumBorder(),
                            liquidBackdropLayer: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: constraints.maxWidth,
                              maxWidth: constraints.maxWidth,
                              minHeight: constraints.maxHeight,
                              maxHeight: constraints.maxHeight,
                              child: Transform.translate(
                                key: const ValueKey(
                                  'liquid-toggle-track-source-translation',
                                ),
                                offset: Offset(-indicatorLeft, -_trackPadding),
                                transformHitTests: false,
                                child: Transform.scale(
                                  key: const ValueKey(
                                    'liquid-toggle-track-source-scale',
                                  ),
                                  alignment: FractionalOffset(
                                    (indicatorLeft + _cellWidth / 2) /
                                        constraints.maxWidth,
                                    (_trackPadding + indicatorHeight / 2) /
                                        constraints.maxHeight,
                                  ),
                                  scaleX: trackScaleX,
                                  scaleY: trackScaleY,
                                  transformHitTests: false,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      constraints.maxHeight / 2,
                                    ),
                                    child: SizedBox(
                                      key: const ValueKey(
                                        'liquid-toggle-track-source',
                                      ),
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      child: ColoredBox(color: trackColor),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: Stack(
                              key: const ValueKey(
                                'liquid-glass-accent-content-layer',
                              ),
                              fit: StackFit.expand,
                              children: [
                                for (
                                  var index = 0;
                                  index < widget.items.length;
                                  index++
                                )
                                  IgnorePointer(
                                    child: Opacity(
                                      opacity: (1 - (position - index).abs())
                                          .clamp(0, 1),
                                      child: ExcludeSemantics(
                                        child: _LiquidNavigationContent(
                                          item: widget.items[index],
                                          color: selectedIconColor,
                                          labelColor: Colors.transparent,
                                          selected: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: _LiquidAmbientHighlight(
                                      progress: progress,
                                      devicePixelRatio:
                                          MediaQuery.devicePixelRatioOf(
                                            context,
                                          ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: _LiquidInnerShadow(
                                      progress: progress,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      key: const ValueKey('liquid-selected-label-layer'),
                      start: indicatorStart,
                      top: _trackPadding,
                      width: max(_cellWidth, 1),
                      height: max(indicatorHeight, 1),
                      child: IgnorePointer(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                          transformHitTests: false,
                          child: ExcludeSemantics(
                            child: _LiquidNavigationContent(
                              item: widget.items[committedIndex],
                              color: Colors.transparent,
                              labelColor: selectedLabelColor,
                              labelKey: const ValueKey(
                                'liquid-accent-label-selected',
                              ),
                              selected: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _LiquidTrackBackdrop(
                        color: trackColor,
                        exclusion: indicatorExclusion,
                      ),
                    ),
                    PositionedDirectional(
                      key: const ValueKey('liquid-toggle-outer-shadow'),
                      start: indicatorStart,
                      top: _trackPadding,
                      width: max(_cellWidth, 1),
                      height: max(indicatorHeight, 1),
                      child: IgnorePointer(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                          transformHitTests: false,
                          child: const CustomPaint(
                            painter: _LiquidOuterShadowPainter(),
                            child: SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      key: const ValueKey('liquid-glass-content-layer'),
                      child: ClipPath(
                        clipper: _OutsideIndicatorClipper(indicatorExclusion),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _trackPadding,
                          ),
                          child: Row(
                            children: [
                              for (
                                var index = 0;
                                index < widget.items.length;
                                index++
                              )
                                Expanded(
                                  child: _LiquidNavigationItem(
                                    key: ValueKey(
                                      'liquid-navigation-item-$index',
                                    ),
                                    item: widget.items[index],
                                    selected: index == committedIndex,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      key: const ValueKey('liquid-navigation-semantics-layer'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _trackPadding,
                        ),
                        child: Row(
                          children: [
                            for (
                              var index = 0;
                              index < widget.items.length;
                              index++
                            )
                              Expanded(
                                child: Semantics(
                                  key: ValueKey(
                                    'liquid-navigation-semantics-$index',
                                  ),
                                  container: true,
                                  selected: index == committedIndex,
                                  button: true,
                                  label: intl.Intl.message(
                                    widget.items[index].label.name,
                                  ),
                                  onTap: () => _activateItem(index),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                          ],
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

class _LiquidTrackBackdrop extends StatelessWidget {
  final Color color;
  final Rect exclusion;

  const _LiquidTrackBackdrop({required this.color, required this.exclusion});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _OutsideIndicatorClipper(exclusion),
      child: BackdropFilter(
        key: const ValueKey('liquid-toggle-track-backdrop-filter'),
        filter: ui.ImageFilter.matrix(Matrix4.identity().storage),
        child: ColoredBox(
          key: const ValueKey('liquid-toggle-track-color'),
          color: color,
        ),
      ),
    );
  }
}

class _OutsideIndicatorClipper extends CustomClipper<Path> {
  final Rect exclusion;

  const _OutsideIndicatorClipper(this.exclusion);

  @override
  Path getClip(Size size) {
    final outer = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      );
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          exclusion,
          Radius.circular(exclusion.height / 2),
        ),
      );
    return Path.combine(PathOperation.difference, outer, inner);
  }

  @override
  bool shouldReclip(covariant _OutsideIndicatorClipper oldClipper) {
    return oldClipper.exclusion != exclusion;
  }
}

class _LiquidNavigationItem extends StatelessWidget {
  final NavigationItem item;
  final bool selected;

  const _LiquidNavigationItem({
    super.key,
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? miuixOnSurfaceContainer(Theme.brightnessOf(context))
        : context.colorScheme.onSurfaceVariant;
    return ExcludeSemantics(
      child: _LiquidNavigationContent(
        item: item,
        color: color,
        selected: selected,
      ),
    );
  }
}

class _LiquidNavigationContent extends StatelessWidget {
  final NavigationItem item;
  final Color color;
  final Color? labelColor;
  final Key? labelKey;
  final bool selected;

  const _LiquidNavigationContent({
    required this.item,
    required this.color,
    this.labelColor,
    this.labelKey,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
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
            key: labelKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelSmall?.copyWith(
              color: labelColor ?? color,
              fontSize: 11,
              height: 1.15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidOuterShadowPainter extends CustomPainter {
  const _LiquidOuterShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final capsule = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final layerRect = Rect.fromLTRB(-8, -8, size.width + 8, size.height + 8);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas
      ..saveLayer(layerRect, Paint())
      ..drawRRect(capsule.shift(const Offset(0, 4 / 6)), shadowPaint)
      ..drawRRect(capsule, Paint()..blendMode = BlendMode.clear)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidOuterShadowPainter oldDelegate) => false;
}

class _LiquidInnerShadow extends StatelessWidget {
  final double progress;

  const _LiquidInnerShadow({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) {
      return const SizedBox.expand();
    }
    final radius = 4 * progress;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: radius,
        sigmaY: radius,
        tileMode: TileMode.decal,
      ),
      child: CustomPaint(
        key: const ValueKey('liquid-toggle-inner-shadow'),
        painter: _LiquidInnerShadowPainter(progress),
      ),
    );
  }
}

class _LiquidInnerShadowPainter extends CustomPainter {
  final double progress;

  const _LiquidInnerShadowPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final radius = 4 * progress;
    final rect = Offset.zero & size;
    final capsule = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    canvas
      ..save()
      ..clipRRect(capsule)
      ..saveLayer(rect, Paint());
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15 * progress);
    canvas.drawRRect(capsule, shadowPaint);
    canvas.drawRRect(
      capsule.shift(Offset(0, radius)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidInnerShadowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LiquidAmbientHighlight extends StatefulWidget {
  final double progress;
  final double devicePixelRatio;

  const _LiquidAmbientHighlight({
    required this.progress,
    required this.devicePixelRatio,
  });

  @override
  State<_LiquidAmbientHighlight> createState() =>
      _LiquidAmbientHighlightState();
}

class _LiquidAmbientHighlightState extends State<_LiquidAmbientHighlight> {
  static Future<ui.FragmentProgram>? _programFuture;

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadProgram();
  }

  Future<void> _loadProgram() async {
    if (!ui.ImageFilter.isShaderFilterSupported) {
      return;
    }
    try {
      final program = await (_programFuture ??= ui.FragmentProgram.fromAsset(
        'shaders/liquid_ambient_highlight.frag',
      ));
      if (!mounted) {
        return;
      }
      setState(() {
        _program = program;
      });
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'fl_clash',
          context: ErrorDescription(
            'while loading the liquid ambient highlight shader',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _shader ??= _program?.fragmentShader();
    return CustomPaint(
      painter: _LiquidAmbientHighlightPainter(
        widget.progress,
        widget.devicePixelRatio,
        _shader,
      ),
    );
  }
}

class _LiquidAmbientHighlightPainter extends CustomPainter {
  final double progress;
  final double devicePixelRatio;
  final ui.FragmentShader? shader;

  const _LiquidAmbientHighlightPainter(
    this.progress,
    this.devicePixelRatio,
    this.shader,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final rect = Offset.zero & size;
    final capsule = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    final paint = Paint()..style = PaintingStyle.stroke;
    if (shader != null) {
      shader!
        ..setFloat(0, size.width * devicePixelRatio)
        ..setFloat(1, size.height * devicePixelRatio)
        ..setFloat(2, size.height * devicePixelRatio / 2)
        ..setFloat(3, size.height * devicePixelRatio / 2)
        ..setFloat(4, size.height * devicePixelRatio / 2)
        ..setFloat(5, size.height * devicePixelRatio / 2)
        ..setFloat(6, pi / 4)
        ..setFloat(7, 1)
        ..setFloat(8, 0.38 * progress);
      paint.shader = shader;
    } else {
      paint.color = Colors.white.withValues(alpha: 0.38 * progress);
    }
    final widthPx = 0.5 / 1.5 * devicePixelRatio;
    paint
      ..strokeWidth = (widthPx.ceil() * 2) / devicePixelRatio
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5 / 3);
    canvas
      ..save()
      ..clipRRect(capsule)
      ..drawRRect(capsule, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidAmbientHighlightPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.devicePixelRatio != devicePixelRatio ||
        oldDelegate.shader != shader;
  }
}
