import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final ValueNotifier<int> nativeLiquidNavigationRouteDepth = ValueNotifier(0);
final NavigatorObserver nativeLiquidNavigationRouteObserver =
    _NativeLiquidNavigationRouteObserver();

class _NativeLiquidNavigationRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  void _updateDepth() {
    nativeLiquidNavigationRouteDepth.value = (_routes.length - 1).clamp(0, 1);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _updateDepth();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _updateDepth();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _updateDepth();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) {
      _routes[index] = newRoute;
    } else {
      if (oldRoute != null) {
        _routes.remove(oldRoute);
      }
      if (newRoute != null) {
        _routes.add(newRoute);
      }
    }
    _updateDepth();
  }
}

class NativeLiquidNavigationBridge extends StatefulWidget {
  final List<String> labels;
  final List<String> pageKeys;
  final int selectedIndex;
  final bool liquidGlass;
  final ValueChanged<int> onSelected;
  final Widget child;

  const NativeLiquidNavigationBridge({
    super.key,
    required this.labels,
    required this.pageKeys,
    required this.selectedIndex,
    required this.liquidGlass,
    required this.onSelected,
    required this.child,
  });

  @override
  State<NativeLiquidNavigationBridge> createState() =>
      _NativeLiquidNavigationBridgeState();
}

class _NativeLiquidNavigationBridgeState
    extends State<NativeLiquidNavigationBridge> {
  static const MethodChannel _channel = MethodChannel(
    'com.follow.clash/liquid_navigation',
  );

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethodCall);
    nativeLiquidNavigationRouteDepth.addListener(_synchronize);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronize();
  }

  @override
  void didUpdateWidget(covariant NativeLiquidNavigationBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _synchronize();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onSelected' || call.arguments is! int) {
      throw MissingPluginException();
    }
    final index = call.arguments as int;
    if (index >= 0 && index < widget.labels.length) {
      widget.onSelected(index);
    }
  }

  void _synchronize() {
    if (!mounted) {
      return;
    }
    final brightness = Theme.brightnessOf(context);
    final direction = Directionality.of(context);
    unawaited(
      _channel.invokeMethod<void>('update', <String, Object>{
        'visible': nativeLiquidNavigationRouteDepth.value == 0,
        'labels': widget.labels,
        'pageKeys': widget.pageKeys,
        'selectedIndex': widget.selectedIndex,
        'liquidGlass': widget.liquidGlass,
        'dark': brightness == Brightness.dark,
        'rtl': direction == TextDirection.rtl,
      }),
    );
  }

  @override
  void dispose() {
    nativeLiquidNavigationRouteDepth.removeListener(_synchronize);
    _channel.setMethodCallHandler(null);
    unawaited(_channel.invokeMethod<void>('hide'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
