import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeLiquidNavigationBridge extends StatefulWidget {
  final List<String> labels;
  final List<String> pageKeys;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  const NativeLiquidNavigationBridge({
    super.key,
    required this.labels,
    required this.pageKeys,
    required this.selectedIndex,
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
    final brightness = Theme.brightnessOf(context);
    final direction = Directionality.of(context);
    unawaited(
      _channel.invokeMethod<void>('update', <String, Object>{
        'visible': true,
        'labels': widget.labels,
        'pageKeys': widget.pageKeys,
        'selectedIndex': widget.selectedIndex,
        'dark': brightness == Brightness.dark,
        'rtl': direction == TextDirection.rtl,
      }),
    );
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_channel.invokeMethod<void>('hide'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
