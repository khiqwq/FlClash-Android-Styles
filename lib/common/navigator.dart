import 'package:animations/animations.dart';
import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BaseNavigator {
  static Future<T?> push<T>(
    BuildContext context,
    Widget child, {
    @visibleForTesting bool? isDesktop,
  }) async {
    final useDesktopRoute = shouldUseCommonDesktopRoute(
      isDesktop: isDesktop ?? system.isDesktop,
      isMobileView: globalState.container.read(isMobileViewProvider),
    );
    if (useDesktopRoute) {
      return Navigator.of(
        context,
      ).push<T>(CommonDesktopRoute(builder: (context) => child));
    }
    return Navigator.of(
      context,
    ).push<T>(CommonRoute(builder: (context) => child));
  }
}

@visibleForTesting
bool shouldUseCommonDesktopRoute({
  required bool isDesktop,
  required bool isMobileView,
}) {
  return isDesktop && !isMobileView;
}

bool shouldUseNestedHomeNavigator({
  required bool isAndroid,
  required bool isMobileView,
}) {
  return !isAndroid && !isMobileView;
}

abstract interface class CommonRouteResultHost {
  void updateCurrentResult(Object? result);
}

mixin CommonRouteResultMixin<T> on Route<T> implements CommonRouteResultHost {
  T? _currentResult;

  @override
  T? get currentResult => _currentResult;

  @override
  void updateCurrentResult(Object? result) {
    switch (result) {
      case null:
        _currentResult = null;
      case final T typedResult:
        _currentResult = typedResult;
      default:
        throw ArgumentError.value(result, 'result');
    }
  }
}

const commonSharedXPageTransitions = SharedAxisPageTransitionsBuilder(
  transitionType: SharedAxisTransitionType.horizontal,
  fillColor: Colors.transparent,
);
const commonSurfaceSharedXPageTransitions =
    SurfaceSharedAxisPageTransitionsBuilder();

PageTransitionsTheme buildPageTransitionsTheme({required bool predictiveBack}) {
  return PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: predictiveBack
          ? const DirectPreviousPredictiveBackPageTransitionsBuilder()
          : commonSurfaceSharedXPageTransitions,
      TargetPlatform.windows: commonSharedXPageTransitions,
      TargetPlatform.linux: commonSharedXPageTransitions,
      TargetPlatform.macOS: commonSharedXPageTransitions,
    },
  );
}

class SurfaceSharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const SurfaceSharedAxisPageTransitionsBuilder({
    this.fillColor,
    this.includeSurface = true,
  });

  final Color? fillColor;
  final bool includeSurface;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final surface = fillColor ?? Theme.of(context).colorScheme.surface;
    final transition = SharedAxisPageTransitionsBuilder(
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: surface,
    ).buildTransitions(route, context, animation, secondaryAnimation, child);
    if (!includeSurface) {
      return transition;
    }
    return ColoredBox(
      key: const ValueKey('common-route-transition-surface'),
      color: surface,
      child: transition,
    );
  }
}

class DirectPreviousPredictiveBackPageTransitionsBuilder
    extends PredictiveBackPageTransitionsBuilder {
  const DirectPreviousPredictiveBackPageTransitionsBuilder({
    super.fallbackColor,
  });

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _DirectPreviousBackPreview(
      route: route,
      surface: fallbackColor ?? Theme.of(context).colorScheme.surface,
      child: SurfaceSharedAxisPageTransitionsBuilder(
        fillColor: fallbackColor,
        includeSurface: false,
      ).buildTransitions(route, context, animation, secondaryAnimation, child),
    );
  }
}

class PredictiveBackCoordinator extends StatefulWidget {
  const PredictiveBackCoordinator({super.key, required this.child});

  final Widget child;

  @override
  State<PredictiveBackCoordinator> createState() =>
      _PredictiveBackCoordinatorState();
}

class _PredictiveBackCoordinatorState extends State<PredictiveBackCoordinator>
    with WidgetsBindingObserver {
  final Set<_DirectPreviousBackPreviewState> _owners = {};
  _PredictiveBackTransaction? _transaction;
  _PredictiveBackTransaction? _settlingTransaction;
  int _nextTransactionId = 0;

  void _attachOwner(_DirectPreviousBackPreviewState owner) {
    _owners.add(owner);
  }

  void _detachOwner(_DirectPreviousBackPreviewState owner) {
    _owners.remove(owner);
    _ownerBecameUnavailable(owner);
  }

  void _ownerBecameUnavailable(_DirectPreviousBackPreviewState owner) {
    final transaction = _transaction;
    if (transaction != null &&
        identical(transaction.owner, owner) &&
        !transaction.aborted) {
      _abortTransaction(transaction, rebuild: false, deferOverlayRestore: true);
    }
  }

  void _abortTransaction(
    _PredictiveBackTransaction transaction, {
    required bool rebuild,
    required bool deferOverlayRestore,
  }) {
    if (transaction.aborted) {
      return;
    }
    transaction.aborted = true;
    _settlingTransaction = transaction;
    transaction.owner._forceAbort(
      transaction.id,
      transaction.navigator,
      transaction.route,
      rebuild: rebuild,
      deferOverlayRestore: deferOverlayRestore,
    );
    _scheduleSettlementCheck(transaction);
  }

  void _completeSettlement(_PredictiveBackTransaction transaction) {
    if (!identical(_settlingTransaction, transaction)) {
      return;
    }
    _settlingTransaction = null;
    transaction.owner._forceCompleteSettlement(
      transaction.id,
      transaction.navigator,
      transaction.route,
    );
  }

  void _scheduleSettlementCheck(_PredictiveBackTransaction transaction) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_settlingTransaction, transaction)) {
        return;
      }
      if (!transaction.navigator.userGestureInProgress) {
        _settlingTransaction = null;
        transaction.owner._finishSettlement(transaction.id);
        return;
      }
      final canContinue = transaction.owner._canContinueSettlement(
        transaction.id,
        transaction.route,
      );
      final animationCompleted = transaction.owner._animationCompleted(
        transaction.id,
        transaction.route,
      );
      if (!canContinue || animationCompleted) {
        if (transaction.settlementChecks == 0) {
          transaction.settlementChecks++;
          _scheduleSettlementCheck(transaction);
          return;
        }
        _completeSettlement(transaction);
        return;
      }
      _scheduleSettlementCheck(transaction);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent) {
      return false;
    }
    if (_transaction != null) {
      return true;
    }
    for (final owner in _owners.toList().reversed) {
      if (!owner._isEnabled) {
        continue;
      }
      final transaction = _PredictiveBackTransaction(
        id: ++_nextTransactionId,
        owner: owner,
        navigator: owner._navigator!,
        route: owner._route,
      );
      _transaction = transaction;
      if (owner._startGesture(transaction.id, transaction.route)) {
        return true;
      }
      _transaction = null;
    }
    return false;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    final transaction = _transaction;
    if (transaction == null || transaction.aborted) {
      return;
    }
    if (!transaction.owner._canContinueGesture(
      transaction.id,
      transaction.route,
    )) {
      _abortTransaction(transaction, rebuild: true, deferOverlayRestore: false);
      return;
    }
    transaction.owner._updateGesture(transaction.id, transaction.route);
  }

  @override
  void handleCancelBackGesture() {
    final transaction = _transaction;
    if (transaction == null) {
      return;
    }
    _transaction = null;
    if (transaction.aborted) {
      return;
    }
    if (!transaction.owner._canContinueGesture(
      transaction.id,
      transaction.route,
    )) {
      _abortTransaction(transaction, rebuild: true, deferOverlayRestore: false);
      return;
    }
    _settlingTransaction = transaction;
    transaction.owner._cancelGesture(transaction.id, transaction.route);
    _scheduleSettlementCheck(transaction);
  }

  @override
  void handleCommitBackGesture() {
    final transaction = _transaction;
    if (transaction == null) {
      return;
    }
    _transaction = null;
    if (transaction.aborted) {
      return;
    }
    if (!transaction.owner._canContinueGesture(
      transaction.id,
      transaction.route,
    )) {
      _abortTransaction(transaction, rebuild: true, deferOverlayRestore: false);
      return;
    }
    transaction.owner._commitGesture(transaction.id, transaction.route);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    final transaction = _transaction;
    _transaction = null;
    if (transaction != null && !transaction.aborted) {
      _abortTransaction(
        transaction,
        rebuild: false,
        deferOverlayRestore: false,
      );
    }
    final settlingTransaction = _settlingTransaction;
    if (settlingTransaction != null) {
      _completeSettlement(settlingTransaction);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _PredictiveBackTransaction {
  _PredictiveBackTransaction({
    required this.id,
    required this.owner,
    required this.navigator,
    required this.route,
  });

  final int id;
  final _DirectPreviousBackPreviewState owner;
  final NavigatorState navigator;
  final PageRoute<dynamic> route;
  bool aborted = false;
  int settlementChecks = 0;
}

class _DirectPreviousBackPreview extends StatefulWidget {
  final PageRoute<dynamic> route;
  final Color surface;
  final Widget child;

  const _DirectPreviousBackPreview({
    required this.route,
    required this.surface,
    required this.child,
  });

  @override
  State<_DirectPreviousBackPreview> createState() =>
      _DirectPreviousBackPreviewState();
}

class _DirectPreviousBackPreviewState
    extends State<_DirectPreviousBackPreview> {
  _PredictiveBackCoordinatorState? _coordinator;
  int? _activeTransactionId;
  int? _settlingTransactionId;
  int? _visualTransactionId;
  int _visualRevision = 0;
  bool _previousRouteVisible = false;
  bool _wasCurrent = false;

  bool get _isEnabled {
    return _navigator != null &&
        widget.route.isCurrent &&
        widget.route.popGestureEnabled;
  }

  NavigatorState? get _navigator {
    return widget.route.navigator;
  }

  PageRoute<dynamic> get _route {
    return widget.route;
  }

  bool _animationCompleted(int transactionId, PageRoute<dynamic> route) {
    return _settlingTransactionId == transactionId &&
        route.animation?.status == AnimationStatus.completed;
  }

  void _updateOverlayOpacity(
    PageRoute<dynamic> route,
    bool previousRouteVisible,
  ) {
    final entries = route.overlayEntries;
    if (entries.isNotEmpty) {
      entries.first.opaque = previousRouteVisible ? false : route.opaque;
    }
  }

  void _restoreVisual(
    int transactionId,
    PageRoute<dynamic> route, {
    required bool rebuild,
    required bool deferOverlayRestore,
  }) {
    _visualTransactionId = transactionId;
    final revision = ++_visualRevision;
    final visibilityChanged = _previousRouteVisible;
    _previousRouteVisible = false;
    if (visibilityChanged && rebuild && mounted) {
      setState(() {});
    }
    if (deferOverlayRestore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_visualTransactionId != transactionId ||
            _visualRevision != revision) {
          return;
        }
        _updateOverlayOpacity(route, false);
      });
    } else {
      _updateOverlayOpacity(route, false);
    }
  }

  void _showPreview(int transactionId, PageRoute<dynamic> route) {
    _visualTransactionId = transactionId;
    _visualRevision++;
    final visibilityChanged = !_previousRouteVisible;
    _previousRouteVisible = true;
    if (visibilityChanged && mounted) {
      setState(() {});
    }
    _updateOverlayOpacity(route, true);
  }

  void _forceAnimationCompleted(PageRoute<dynamic> route) {
    if (!route.isActive) {
      return;
    }
    route.handleUpdateBackGestureProgress(progress: 0);
  }

  bool _startGesture(int transactionId, PageRoute<dynamic> route) {
    if (!_isEnabled || !identical(widget.route, route)) {
      return false;
    }
    _activeTransactionId = transactionId;
    _settlingTransactionId = null;
    route.handleStartBackGesture(progress: 0);
    _showPreview(transactionId, route);
    return true;
  }

  bool _canContinueGesture(int transactionId, PageRoute<dynamic> route) {
    return _activeTransactionId == transactionId &&
        identical(widget.route, route) &&
        route.isActive &&
        route.isCurrent;
  }

  bool _canContinueSettlement(int transactionId, PageRoute<dynamic> route) {
    return _settlingTransactionId == transactionId &&
        identical(widget.route, route) &&
        route.isActive &&
        route.isCurrent;
  }

  void _updateGesture(int transactionId, PageRoute<dynamic> route) {
    if (_activeTransactionId != transactionId ||
        !identical(widget.route, route)) {
      return;
    }
    route.handleUpdateBackGestureProgress(progress: 0);
    _showPreview(transactionId, route);
  }

  void _cancelGesture(int transactionId, PageRoute<dynamic> route) {
    if (_activeTransactionId != transactionId ||
        !identical(widget.route, route)) {
      return;
    }
    _activeTransactionId = null;
    _settlingTransactionId = transactionId;
    _restoreVisual(
      transactionId,
      route,
      rebuild: true,
      deferOverlayRestore: false,
    );
    route.handleCancelBackGesture();
  }

  void _commitGesture(int transactionId, PageRoute<dynamic> route) {
    if (_activeTransactionId != transactionId ||
        !identical(widget.route, route)) {
      return;
    }
    _activeTransactionId = null;
    route.handleCommitBackGesture();
  }

  void _forceAbort(
    int transactionId,
    NavigatorState navigator,
    PageRoute<dynamic> route, {
    required bool rebuild,
    required bool deferOverlayRestore,
  }) {
    if (_activeTransactionId != transactionId) {
      return;
    }
    _activeTransactionId = null;
    _settlingTransactionId = transactionId;
    _restoreVisual(
      transactionId,
      route,
      rebuild: rebuild,
      deferOverlayRestore: deferOverlayRestore,
    );
    if (deferOverlayRestore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finishForceAbort(transactionId, navigator, route);
      });
    } else {
      _finishForceAbort(transactionId, navigator, route);
    }
  }

  void _finishForceAbort(
    int transactionId,
    NavigatorState navigator,
    PageRoute<dynamic> route,
  ) {
    if (_settlingTransactionId != transactionId) {
      return;
    }
    if (route.isActive) {
      _forceAnimationCompleted(route);
      if (navigator.userGestureInProgress) {
        route.handleCancelBackGesture();
      } else {
        _settlingTransactionId = null;
      }
    } else if (navigator.userGestureInProgress) {
      _settlingTransactionId = null;
      navigator.didStopUserGesture();
    }
  }

  void _forceCompleteSettlement(
    int transactionId,
    NavigatorState navigator,
    PageRoute<dynamic> route,
  ) {
    if (_settlingTransactionId != transactionId) {
      return;
    }
    _forceAnimationCompleted(route);
    _settlingTransactionId = null;
    if (navigator.userGestureInProgress) {
      navigator.didStopUserGesture();
    }
  }

  void _finishSettlement(int transactionId) {
    if (_settlingTransactionId == transactionId) {
      _settlingTransactionId = null;
    }
  }

  void _attachCoordinator() {
    final coordinator = context
        .findAncestorStateOfType<_PredictiveBackCoordinatorState>();
    if (identical(_coordinator, coordinator)) {
      return;
    }
    _coordinator?._detachOwner(this);
    _coordinator = coordinator;
    _coordinator?._attachOwner(this);
  }

  @override
  void initState() {
    super.initState();
    _wasCurrent = widget.route.isCurrent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachCoordinator();
    final isCurrent = ModalRoute.isCurrentOf(context) ?? widget.route.isCurrent;
    if (_wasCurrent && !isCurrent) {
      _coordinator?._ownerBecameUnavailable(this);
    }
    _wasCurrent = isCurrent;
  }

  @override
  void dispose() {
    _coordinator?._detachOwner(this);
    _coordinator = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_previousRouteVisible) {
      return Offstage(child: widget.child);
    }
    return ColoredBox(
      key: const ValueKey('common-route-transition-surface'),
      color: widget.surface,
      child: widget.child,
    );
  }
}

class CommonDesktopRoute<T> extends PageRoute<T>
    with CommonRouteResultMixin<T> {
  final Widget Function(BuildContext context) builder;

  CommonDesktopRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget result = builder(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: FadeTransition(opacity: animation, child: result),
    );
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);
}

class CommonRoute<T> extends MaterialPageRoute<T>
    with CommonRouteResultMixin<T> {
  CommonRoute({required super.builder});
}

final Animatable<Offset> _kRightMiddleTween = Tween<Offset>(
  begin: const Offset(1.0, 0.0),
  end: Offset.zero,
);
final Animatable<Offset> _kMiddleLeftTween = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(-1.0 / 3.0, 0.0),
);

class CommonPageTransitionsBuilder extends PageTransitionsBuilder {
  const CommonPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CommonPageTransition(
      context: context,
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }
}

class CommonPageTransition extends StatefulWidget {
  const CommonPageTransition({
    super.key,
    required this.context,
    required this.primaryRouteAnimation,
    required this.secondaryRouteAnimation,
    required this.child,
    required this.linearTransition,
  });

  final Widget child;

  final Animation<double> primaryRouteAnimation;

  final Animation<double> secondaryRouteAnimation;

  final BuildContext context;

  final bool linearTransition;

  static Widget? delegatedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    final CurvedAnimation animation = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
    );
    final Animation<Offset> delegatedPositionAnimation = animation.drive(
      _kMiddleLeftTween,
    );
    animation.dispose();

    assert(debugCheckHasDirectionality(context));
    final TextDirection textDirection = Directionality.of(context);
    return SlideTransition(
      position: delegatedPositionAnimation,
      textDirection: textDirection,
      transformHitTests: false,
      child: child,
    );
  }

  @override
  State<CommonPageTransition> createState() => _CommonPageTransitionState();
}

class _CommonPageTransitionState extends State<CommonPageTransition> {
  late Animation<Offset> _primaryPositionAnimation;
  late Animation<Offset> _secondaryPositionAnimation;
  late Animation<Decoration> _primaryShadowAnimation;
  CurvedAnimation? _primaryPositionCurve;
  CurvedAnimation? _secondaryPositionCurve;
  CurvedAnimation? _primaryShadowCurve;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant CommonPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryRouteAnimation != widget.primaryRouteAnimation ||
        oldWidget.secondaryRouteAnimation != widget.secondaryRouteAnimation ||
        oldWidget.linearTransition != widget.linearTransition) {
      _disposeCurve();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _disposeCurve();
    super.dispose();
  }

  void _disposeCurve() {
    _primaryPositionCurve?.dispose();
    _secondaryPositionCurve?.dispose();
    _primaryShadowCurve?.dispose();
    _primaryPositionCurve = null;
    _secondaryPositionCurve = null;
    _primaryShadowCurve = null;
  }

  void _setupAnimation() {
    if (!widget.linearTransition) {
      _primaryPositionCurve = CurvedAnimation(
        parent: widget.primaryRouteAnimation,
        curve: Curves.fastEaseInToSlowEaseOut,
        reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
      );
      _secondaryPositionCurve = CurvedAnimation(
        parent: widget.secondaryRouteAnimation,
        curve: Curves.linearToEaseOut,
        reverseCurve: Curves.easeInToLinear,
      );
      _primaryShadowCurve = CurvedAnimation(
        parent: widget.primaryRouteAnimation,
        curve: Curves.linearToEaseOut,
      );
    }
    _primaryPositionAnimation =
        (_primaryPositionCurve ?? widget.primaryRouteAnimation).drive(
          _kRightMiddleTween,
        );
    _secondaryPositionAnimation =
        (_secondaryPositionCurve ?? widget.secondaryRouteAnimation).drive(
          _kMiddleLeftTween,
        );
    _primaryShadowAnimation =
        (_primaryShadowCurve ?? widget.primaryRouteAnimation).drive(
          DecorationTween(
            begin: const _CommonEdgeShadowDecoration(),
            end: const _CommonEdgeShadowDecoration(<Color>[
              Color(0x04000000),
              Colors.transparent,
            ]),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final TextDirection textDirection = Directionality.of(context);
    return SlideTransition(
      position: _secondaryPositionAnimation,
      textDirection: textDirection,
      transformHitTests: false,
      child: SlideTransition(
        position: _primaryPositionAnimation,
        textDirection: textDirection,
        child: DecoratedBoxTransition(
          decoration: _primaryShadowAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

class _CommonEdgeShadowDecoration extends Decoration {
  final List<Color>? _colors;

  const _CommonEdgeShadowDecoration([this._colors]);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _CommonEdgeShadowPainter(this, onChanged);
  }
}

class _CommonEdgeShadowPainter extends BoxPainter {
  _CommonEdgeShadowPainter(this._decoration, super.onChanged)
    : assert(_decoration._colors == null || _decoration._colors.length > 1);

  final _CommonEdgeShadowDecoration _decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final List<Color>? colors = _decoration._colors;
    if (colors == null) {
      return;
    }

    final double shadowWidth = 0.05 * configuration.size!.width;
    final double shadowHeight = configuration.size!.height;
    final double bandWidth = shadowWidth / (colors.length - 1);

    final TextDirection? textDirection = configuration.textDirection;
    assert(textDirection != null);
    final (double shadowDirection, double start) = switch (textDirection!) {
      TextDirection.rtl => (1, offset.dx + configuration.size!.width),
      TextDirection.ltr => (-1, offset.dx),
    };

    int bandColorIndex = 0;
    for (int dx = 0; dx < shadowWidth; dx += 1) {
      if (dx ~/ bandWidth != bandColorIndex) {
        bandColorIndex += 1;
      }
      final Paint paint = Paint()
        ..color = Color.lerp(
          colors[bandColorIndex],
          colors[bandColorIndex + 1],
          (dx % bandWidth) / bandWidth,
        )!;
      final double x = start + shadowDirection * dx;
      canvas.drawRect(
        Rect.fromLTWH(x - 1.0, offset.dy, 1.0, shadowHeight),
        paint,
      );
    }
  }
}
