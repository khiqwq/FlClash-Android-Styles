import 'dart:async';

import 'package:flutter/widgets.dart';

import 'inherited.dart';

class CommonPopScope extends StatefulWidget {
  final Widget child;
  final FutureOr<void> Function(BuildContext context)? onPop;
  final bool canPop;

  const CommonPopScope({
    super.key,
    required this.child,
    this.onPop,
    this.canPop = true,
  });

  @override
  State<CommonPopScope> createState() => _CommonPopScopeState();
}

class _CommonPopScopeState extends State<CommonPopScope> {
  late final _BackLayerRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = _BackLayerRegistry();
  }

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final hasBackLayer = route?.willHandlePopInternally == true;
    return _BackLayerRegistryScope(
      registry: _registry,
      child: Builder(
        builder: (context) {
          final registry = _BackLayerRegistryScope.of(context);
          return AnimatedBuilder(
            animation: registry,
            builder: (context, child) {
              return PopScope(
                canPop:
                    widget.canPop ||
                    hasBackLayer ||
                    registry.hasActiveFor(route),
                onPopInvokedWithResult: widget.onPop == null
                    ? null
                    : (didPop, _) {
                        if (!didPop) {
                          widget.onPop!(context);
                        }
                      },
                child: child!,
              );
            },
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _BackLayerRegistry extends ChangeNotifier {
  final Map<ModalRoute<dynamic>, int> _activeRoutes =
      <ModalRoute<dynamic>, int>{};
  bool _notificationScheduled = false;
  bool _disposed = false;

  bool hasActiveFor(ModalRoute<dynamic>? route) {
    return route != null && (_activeRoutes[route] ?? 0) > 0;
  }

  void attach(ModalRoute<dynamic> route) {
    _activeRoutes.update(route, (count) => count + 1, ifAbsent: () => 1);
    _scheduleNotification();
  }

  void detach(ModalRoute<dynamic> route) {
    final count = _activeRoutes[route];
    if (count == null) {
      return;
    }
    if (count == 1) {
      _activeRoutes.remove(route);
    } else {
      _activeRoutes[route] = count - 1;
    }
    _scheduleNotification();
  }

  void _scheduleNotification() {
    if (_notificationScheduled) {
      return;
    }
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _BackLayerRegistryScope extends InheritedNotifier<_BackLayerRegistry> {
  const _BackLayerRegistryScope({
    required _BackLayerRegistry registry,
    required super.child,
  }) : super(notifier: registry);

  static _BackLayerRegistry? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_BackLayerRegistryScope>()
        ?.notifier;
  }

  static _BackLayerRegistry of(BuildContext context) {
    return maybeOf(context)!;
  }
}

class BackLayerScope extends StatefulWidget {
  final Widget child;
  final VoidCallback onBack;
  @visibleForTesting
  final void Function(void Function(Duration) callback)?
  schedulePostFrameCallback;

  const BackLayerScope({
    super.key,
    required this.onBack,
    required this.child,
    @visibleForTesting this.schedulePostFrameCallback,
  });

  @override
  State<BackLayerScope> createState() => _BackLayerScopeState();
}

class _BackLayerScopeState extends State<BackLayerScope> {
  ModalRoute<dynamic>? _route;
  LocalHistoryEntry? _entry;
  _BackLayerRegistry? _registry;
  ModalRoute<dynamic>? _registryRoute;
  bool _isDetaching = false;
  bool _isPageActive = true;
  int _syncRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final isPageActive = PageActivityScope.isActiveOf(context);
    final registry = _BackLayerRegistryScope.maybeOf(context);
    final routeChanged = !identical(_route, route);
    final activityChanged = _isPageActive != isPageActive;
    final registryChanged = !identical(_registry, registry);
    if (!routeChanged && !activityChanged && !registryChanged) {
      return;
    }
    if (registryChanged && !routeChanged && !activityChanged) {
      _detachRegistry();
      _registry = registry;
      _registryRoute = route;
      if (_isPageActive &&
          route != null &&
          widget.schedulePostFrameCallback == null) {
        _registry?.attach(route);
      }
      return;
    }
    _detach();
    _route = route;
    _isPageActive = isPageActive;
    _registry = registry;
    _registryRoute = route;
    final revision = ++_syncRevision;
    if (_isPageActive &&
        route != null &&
        widget.schedulePostFrameCallback == null) {
      _registry?.attach(route);
      final entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: _handleRemove,
      );
      _entry = entry;
      route.addLocalHistoryEntry(entry);
      return;
    }
    final schedulePostFrameCallback =
        widget.schedulePostFrameCallback ??
        WidgetsBinding.instance.addPostFrameCallback;
    schedulePostFrameCallback((_) {
      if (!mounted || revision != _syncRevision) {
        return;
      }
      if (!_isPageActive) {
        widget.onBack();
        return;
      }
      if (route == null) {
        return;
      }
      final entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: _handleRemove,
      );
      _entry = entry;
      route.addLocalHistoryEntry(entry);
    });
  }

  void _handleRemove() {
    _entry = null;
    _detachRegistry();
    if (!_isDetaching && mounted) {
      widget.onBack();
    }
  }

  void _detach() {
    final entry = _entry;
    if (entry != null) {
      _entry = null;
      _isDetaching = true;
      entry.remove();
      _isDetaching = false;
    }
    _detachRegistry();
  }

  void _detachRegistry() {
    final registryRoute = _registryRoute;
    if (registryRoute != null) {
      _registry?.detach(registryRoute);
    }
    _registry = null;
    _registryRoute = null;
  }

  @override
  void dispose() {
    _syncRevision++;
    _detach();
    _route = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
