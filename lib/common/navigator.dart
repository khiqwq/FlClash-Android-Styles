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

class _DirectPreviousBackPreviewState extends State<_DirectPreviousBackPreview>
    with WidgetsBindingObserver {
  bool _acceptedGesture = false;
  bool _previousRouteVisible = false;
  bool _wasCurrent = false;
  NavigatorState? _gestureNavigator;
  int _gestureRevision = 0;

  bool get _isEnabled {
    return widget.route.isCurrent && widget.route.popGestureEnabled;
  }

  void _updateOverlayOpacity(bool previousRouteVisible) {
    final entries = widget.route.overlayEntries;
    if (entries.isNotEmpty) {
      entries.first.opaque = previousRouteVisible ? false : widget.route.opaque;
    }
  }

  void _scheduleGestureAbort(
    bool wasAccepted,
    NavigatorState? gestureNavigator,
    int revision,
  ) {
    final route = widget.route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (revision != _gestureRevision) {
        return;
      }
      final entries = route.overlayEntries;
      if (entries.isNotEmpty) {
        entries.first.opaque = route.opaque;
      }
      if (!wasAccepted) {
        return;
      }
      if (route.isActive) {
        route.handleCancelBackGesture();
      } else if (gestureNavigator?.userGestureInProgress == true) {
        gestureNavigator!.didStopUserGesture();
      }
    });
  }

  void _setPreviousRouteVisible(bool value, {bool rebuild = true}) {
    if (_previousRouteVisible == value) {
      return;
    }
    _previousRouteVisible = value;
    if (rebuild && mounted) {
      setState(() {});
    }
    _updateOverlayOpacity(value);
  }

  void _abortGesture({bool rebuild = true, bool deferOverlayRestore = false}) {
    final wasAccepted = _acceptedGesture;
    final gestureNavigator = _gestureNavigator;
    final revision = ++_gestureRevision;
    _acceptedGesture = false;
    _gestureNavigator = null;
    if (deferOverlayRestore) {
      _previousRouteVisible = false;
      _scheduleGestureAbort(wasAccepted, gestureNavigator, revision);
    } else {
      _setPreviousRouteVisible(false, rebuild: rebuild);
      if (wasAccepted) {
        widget.route.handleCancelBackGesture();
      }
    }
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final gestureInProgress = !backEvent.isButtonEvent && _isEnabled;
    if (!gestureInProgress) {
      return false;
    }
    _acceptedGesture = true;
    _gestureRevision++;
    _gestureNavigator = widget.route.navigator;
    widget.route.handleStartBackGesture(progress: 0);
    _setPreviousRouteVisible(true);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_acceptedGesture) {
      return;
    }
    widget.route.handleUpdateBackGestureProgress(progress: 0);
    _setPreviousRouteVisible(true);
  }

  @override
  void handleCancelBackGesture() {
    if (!_acceptedGesture) {
      return;
    }
    _acceptedGesture = false;
    _gestureRevision++;
    _gestureNavigator = null;
    _setPreviousRouteVisible(false);
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    if (!_acceptedGesture) {
      return;
    }
    if (!widget.route.isCurrent) {
      _abortGesture();
      return;
    }
    _acceptedGesture = false;
    _gestureRevision++;
    _gestureNavigator = null;
    widget.route.handleCommitBackGesture();
  }

  @override
  void initState() {
    super.initState();
    _wasCurrent = widget.route.isCurrent;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrent = ModalRoute.isCurrentOf(context) ?? widget.route.isCurrent;
    if (_wasCurrent && !isCurrent && _acceptedGesture) {
      _abortGesture(rebuild: false, deferOverlayRestore: true);
    }
    _wasCurrent = isCurrent;
  }

  @override
  void dispose() {
    if (_acceptedGesture) {
      _abortGesture(rebuild: false, deferOverlayRestore: true);
    }
    WidgetsBinding.instance.removeObserver(this);
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
