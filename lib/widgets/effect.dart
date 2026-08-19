import 'dart:math';
import 'dart:ui' as ui;

import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/material.dart';

class AndroidGlassSurface extends StatefulWidget {
  final bool blur;
  final bool liquidGlass;
  final BorderRadius borderRadius;
  final Widget child;

  const AndroidGlassSurface({
    super.key,
    required this.blur,
    required this.liquidGlass,
    this.borderRadius = BorderRadius.zero,
    required this.child,
  });

  @override
  State<AndroidGlassSurface> createState() => _AndroidGlassSurfaceState();
}

class _AndroidGlassSurfaceState extends State<AndroidGlassSurface> {
  static Future<ui.FragmentProgram>? _programFuture;
  static bool _shaderLoadFailed = false;

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadProgram();
  }

  @override
  void didUpdateWidget(covariant AndroidGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.liquidGlass && widget.liquidGlass) {
      _loadProgram();
    }
  }

  Future<void> _loadProgram() async {
    if (!widget.liquidGlass ||
        !ui.ImageFilter.isShaderFilterSupported ||
        _program != null ||
        _shaderLoadFailed) {
      return;
    }
    try {
      final program = await (_programFuture ??= ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      ));
      if (!mounted) {
        return;
      }
      setState(() {
        _program = program;
      });
    } on Exception catch (error, stackTrace) {
      _shaderLoadFailed = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'fl_clash',
          context: ErrorDescription('while loading the liquid glass shader'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  ui.ImageFilter _buildFilter() {
    final blur = ui.ImageFilter.blur(
      sigmaX: widget.liquidGlass
          ? AndroidAppearanceTokens.liquidGlassBlurSigma
          : AndroidAppearanceTokens.barBlurSigma,
      sigmaY: widget.liquidGlass
          ? AndroidAppearanceTokens.liquidGlassBlurSigma
          : AndroidAppearanceTokens.barBlurSigma,
      tileMode: TileMode.clamp,
    );
    if (!widget.liquidGlass ||
        !ui.ImageFilter.isShaderFilterSupported ||
        _program == null) {
      return blur;
    }
    _shader?.dispose();
    final shader = _program!.fragmentShader()
      ..setFloat(2, widget.borderRadius.topLeft.x)
      ..setFloat(3, AndroidAppearanceTokens.liquidGlassRefractionHeight)
      ..setFloat(4, AndroidAppearanceTokens.liquidGlassRefractionAmount)
      ..setFloat(5, AndroidAppearanceTokens.liquidGlassChromaticAberration);
    _shader = shader;
    return ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      inner: blur,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appearance = Theme.of(context).extension<AppearanceTheme>();
    final hasEffect =
        widget.blur ||
        widget.liquidGlass ||
        widget.borderRadius != BorderRadius.zero;
    if (appearance?.isAndroid != true || !hasEffect) {
      return widget.child;
    }
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedSuperellipseBorder(borderRadius: widget.borderRadius);
    final surfaceColor = widget.liquidGlass
        ? colorScheme.surface.withValues(
            alpha: AndroidAppearanceTokens.liquidGlassTintOpacity,
          )
        : widget.blur
        ? colorScheme.surface.withValues(
            alpha: AndroidAppearanceTokens.blurredBarTintOpacity,
          )
        : colorScheme.surfaceContainer;
    Widget surface = Stack(
      fit: StackFit.passthrough,
      children: [
        ColoredBox(color: surfaceColor, child: widget.child),
        if (widget.liquidGlass)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(
                        alpha:
                            AndroidAppearanceTokens.liquidGlassHighlightOpacity,
                      ),
                      colorScheme.primary.withValues(
                        alpha: AndroidAppearanceTokens.liquidGlassAccentOpacity,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.38, 1],
                  ),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: widget.borderRadius,
                    side: BorderSide(
                      color: Colors.white.withValues(
                        alpha: AndroidAppearanceTokens.liquidGlassBorderOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (widget.blur || widget.liquidGlass) {
      surface = BackdropFilter(filter: _buildFilter(), child: surface);
    }
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: surface,
    );
  }
}

class EffectGestureDetector extends StatefulWidget {
  final Widget child;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onTap;

  const EffectGestureDetector({
    super.key,
    required this.child,
    this.onLongPress,
    this.onTap,
  });

  @override
  State<EffectGestureDetector> createState() => _EffectGestureDetectorState();
}

class _EffectGestureDetectorState extends State<EffectGestureDetector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: kThemeAnimationDuration,
      curve: Curves.easeOut,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        onLongPressStart: (_) {
          setState(() {
            _scale = 0.95;
          });
        },
        onTap: widget.onTap,
        onLongPressEnd: (_) {
          setState(() {
            _scale = 1;
          });
        },
        child: widget.child,
      ),
    );
  }
}

class CommonExpandIcon extends StatefulWidget {
  final bool expand;

  const CommonExpandIcon({super.key, this.expand = false});

  @override
  State<CommonExpandIcon> createState() => _CommonExpandIconState();
}

class _CommonExpandIconState extends State<CommonExpandIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _iconTurns;

  static final Animatable<double> _iconTurnTween = Tween<double>(
    begin: 0.0,
    end: 0.5,
  ).chain(CurveTween(curve: Curves.fastOutSlowIn));

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = _animationController.drive(_iconTurnTween);
    if (widget.expand) {
      _animationController.value = pi;
    }
  }

  @override
  void didUpdateWidget(covariant CommonExpandIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expand != widget.expand) {
      if (widget.expand) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController.view,
      builder: (_, child) {
        return RotationTransition(turns: _iconTurns, child: child!);
      },
      child: const Icon(Icons.expand_more),
    );
  }
}

Widget commonProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return ProxyDecoratorProvider(
    isProxyDecorator: true,
    child: AnimatedBuilder(
      animation: animation,
      builder: (_, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = ui.lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(scale: scale, child: child);
      },
      child: child,
    ),
  );
}
