import 'dart:math';
import 'dart:ui' as ui;

import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/material.dart';

@immutable
class LiquidGlassUniforms {
  static const int floatCount = 14;

  final Size inputSize;
  final Offset shapeOrigin;
  final Size shapeSize;
  final BorderRadius cornerRadii;
  final double refractionHeight;
  final double refractionAmount;
  final double chromaticAberration;
  final double depthEffect;

  const LiquidGlassUniforms({
    required this.inputSize,
    required this.shapeOrigin,
    required this.shapeSize,
    required this.cornerRadii,
    required this.refractionHeight,
    required this.refractionAmount,
    required this.chromaticAberration,
    required this.depthEffect,
  });

  List<double> get values => <double>[
    inputSize.width,
    inputSize.height,
    shapeOrigin.dx,
    shapeOrigin.dy,
    shapeSize.width,
    shapeSize.height,
    cornerRadii.topLeft.x,
    cornerRadii.topRight.x,
    cornerRadii.bottomRight.x,
    cornerRadii.bottomLeft.x,
    refractionHeight,
    refractionAmount,
    chromaticAberration,
    depthEffect,
  ];

  void apply(ui.FragmentShader shader) {
    final floats = values;
    for (var index = 0; index < floats.length; index++) {
      shader.setFloat(index, floats[index]);
    }
  }
}

class AndroidGlassSurface extends StatefulWidget {
  final bool blur;
  final bool liquidGlass;
  final double liquidProgress;
  final Color? surfaceColor;
  final Color? liquidAccentColor;
  final double? liquidBlurSigma;
  final double? liquidRefractionHeight;
  final double? liquidRefractionAmount;
  final double? liquidChromaticAberration;
  final double liquidDepthEffect;
  final double liquidSamplePadding;
  final bool scaleLiquidBlurWithProgress;
  final Size? liquidSize;
  final BorderRadius borderRadius;
  final OutlinedBorder? shape;
  final Widget child;

  const AndroidGlassSurface({
    super.key,
    required this.blur,
    required this.liquidGlass,
    this.liquidProgress = 1,
    this.surfaceColor,
    this.liquidAccentColor,
    this.liquidBlurSigma,
    this.liquidRefractionHeight,
    this.liquidRefractionAmount,
    this.liquidChromaticAberration,
    this.liquidDepthEffect = 0,
    this.liquidSamplePadding = 40,
    this.scaleLiquidBlurWithProgress = true,
    this.liquidSize,
    this.borderRadius = BorderRadius.zero,
    this.shape,
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

  Size _resolveShapeSize(BoxConstraints constraints) {
    if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
      return Size(constraints.maxWidth, constraints.maxHeight);
    }
    return widget.liquidSize ?? Size.zero;
  }

  ui.ImageFilter _buildFilter(
    BuildContext context,
    Size shapeSize,
    double samplePadding,
  ) {
    final progress = widget.liquidProgress.clamp(0.0, 1.0);
    final configuredBlurSigma =
        widget.liquidBlurSigma ?? AndroidAppearanceTokens.liquidGlassBlurSigma;
    final blurSigma = widget.liquidGlass
        ? max(
            0.001,
            configuredBlurSigma *
                (widget.scaleLiquidBlurWithProgress ? 1 - progress * 0.45 : 1),
          )
        : AndroidAppearanceTokens.barBlurSigma;
    final blur = ui.ImageFilter.blur(
      sigmaX: blurSigma,
      sigmaY: blurSigma,
      tileMode: TileMode.clamp,
    );
    if (!widget.liquidGlass ||
        !ui.ImageFilter.isShaderFilterSupported ||
        _program == null ||
        shapeSize.isEmpty) {
      return blur;
    }
    final inputSize = Size(
      shapeSize.width + samplePadding * 2,
      shapeSize.height + samplePadding * 2,
    );
    final resolvedRadii = widget.borderRadius.resolve(
      Directionality.of(context),
    );
    final defaultIntensity = 0.45 + progress * 0.55;
    final refractionHeight =
        widget.liquidRefractionHeight ??
        AndroidAppearanceTokens.liquidGlassRefractionHeight * defaultIntensity;
    final refractionAmount =
        widget.liquidRefractionAmount ??
        AndroidAppearanceTokens.liquidGlassRefractionAmount * defaultIntensity;
    if (refractionHeight <= 0 || refractionAmount <= 0) {
      return blur;
    }
    final uniforms = LiquidGlassUniforms(
      inputSize: inputSize,
      shapeOrigin: Offset(samplePadding, samplePadding),
      shapeSize: shapeSize,
      cornerRadii: resolvedRadii,
      refractionHeight: refractionHeight,
      refractionAmount: refractionAmount,
      chromaticAberration:
          widget.liquidChromaticAberration ??
          AndroidAppearanceTokens.liquidGlassChromaticAberration *
              defaultIntensity,
      depthEffect: widget.liquidDepthEffect,
    );
    final shader = _shader ??= _program!.fragmentShader();
    uniforms.apply(shader);
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
    final progress = widget.liquidProgress.clamp(0.0, 1.0);
    final rimProgress = progress;
    final shape =
        widget.shape ??
        RoundedSuperellipseBorder(borderRadius: widget.borderRadius);
    final surfaceColor =
        widget.surfaceColor ??
        (widget.liquidGlass
            ? colorScheme.surface.withValues(
                alpha: AndroidAppearanceTokens.liquidGlassTintOpacity,
              )
            : widget.blur
            ? colorScheme.surface.withValues(
                alpha: AndroidAppearanceTokens.blurredBarTintOpacity,
              )
            : colorScheme.surfaceContainer);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shapeSize = _resolveShapeSize(constraints);
        final double samplePadding = widget.liquidGlass
            ? max(widget.liquidSamplePadding, 0.0)
            : 0.0;
        Widget surface = Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            if (widget.blur || widget.liquidGlass)
              Positioned(
                left: -samplePadding,
                top: -samplePadding,
                width: shapeSize.width + samplePadding * 2,
                height: shapeSize.height + samplePadding * 2,
                child: BackdropFilter(
                  filter: _buildFilter(context, shapeSize, samplePadding),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            Positioned.fill(child: ColoredBox(color: surfaceColor)),
            widget.child,
            if (widget.liquidGlass)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('liquid-glass-rim'),
                    painter: _GlassRimPainter(
                      borderRadius: widget.borderRadius,
                      brightness: Theme.brightnessOf(context),
                      intensity: rimProgress,
                    ),
                  ),
                ),
              ),
          ],
        );
        surface = ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: surface,
        );
        return surface;
      },
    );
  }
}

class _GlassRimPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final Brightness brightness;
  final double intensity;

  const _GlassRimPainter({
    required this.borderRadius,
    required this.brightness,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    final path = Path()..addRRect(borderRadius.toRRect(rect).deflate(0.75));
    canvas.save();
    canvas.clipPath(path);
    final innerShadow = Paint()
      ..color = Colors.black.withValues(
        alpha: (brightness == Brightness.dark ? 0.18 : 0.1) * intensity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path.shift(const Offset(0, -1.5)), innerShadow);
    canvas.restore();

    final glow = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        <Color>[
          Colors.white.withValues(alpha: 0.82 * intensity),
          Colors.white.withValues(alpha: 0.2 * intensity),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.34 * intensity),
        ],
        <double>[0, 0.28, 0.68, 1],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.35);
    canvas.drawPath(path, glow);

    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.18 + 0.18 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65;
    canvas.drawPath(path, edge);
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.brightness != brightness ||
        oldDelegate.intensity != intensity;
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
