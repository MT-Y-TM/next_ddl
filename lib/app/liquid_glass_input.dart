import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kyant_glass/kyant_glass.dart';

import '../models/liquid_glass_settings.dart';
import '../utils/background_readability.dart';
import 'background_readability.dart';

class InputGlassTheme extends ThemeExtension<InputGlassTheme> {
  const InputGlassTheme({
    required this.enabled,
    required this.radius,
    this.parameters = const LiquidGlassSettings(),
  });
  final bool enabled;
  final double radius;
  final LiquidGlassSettings parameters;

  @override
  InputGlassTheme copyWith({
    bool? enabled,
    double? radius,
    LiquidGlassSettings? parameters,
  }) => InputGlassTheme(
    enabled: enabled ?? this.enabled,
    radius: radius ?? this.radius,
    parameters: parameters ?? this.parameters,
  );

  @override
  InputGlassTheme lerp(covariant InputGlassTheme? other, double t) =>
      other == null
      ? this
      : InputGlassTheme(
          enabled: t < 0.5 ? enabled : other.enabled,
          radius: radius + (other.radius - radius) * t,
          parameters: LiquidGlassSettings.lerp(parameters, other.parameters, t),
        );
}

/// A retained source shared by inputs. Only the wallpaper is sampled; route
/// contents never become part of their own backdrop, even while navigating.
class InputGlassBackdropShell extends StatefulWidget {
  const InputGlassBackdropShell({
    required this.background,
    required this.child,
    super.key,
  });
  final Widget background;
  final Widget child;

  @override
  State<InputGlassBackdropShell> createState() =>
      _InputGlassBackdropShellState();
}

class _InputGlassBackdropShellState extends State<InputGlassBackdropShell>
    with WidgetsBindingObserver {
  final _backdrop = _WallpaperGlassBackdrop();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void didChangeMetrics() => _backdrop.refreshGeometry();

  void _handleFocusChange() => _backdrop.refreshGeometry();

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    WidgetsBinding.instance.removeObserver(this);
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _backdrop.enabled =
        Theme.of(context).extension<InputGlassTheme>()?.enabled ?? false;
    return BackgroundReadabilityHost(
      background: widget.background,
      onBackgroundPainted: _backdrop.painted,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _backdrop.invalidateGeometry();
          return false;
        },
        child: KyantBackdropScope(controller: _backdrop, child: widget.child),
      ),
    );
  }
}

/// Reuse the shell's paint boundary instead of nesting another boundary that
/// could hide retained wallpaper repaints from contrast analysis.
class _WallpaperGlassBackdrop extends ChangeNotifier implements KyantBackdrop {
  bool _enabled = false;
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (value && _boundary != null) painted(_boundary!);
  }

  bool _disposed = false, _scheduled = false;
  RenderRepaintBoundary? _boundary;
  @override
  ui.Image? image;
  @override
  Rect rect = Rect.zero;
  @override
  Matrix4 imageToGlobal = Matrix4.identity();
  @override
  int revision = 0;

  void painted(RenderRepaintBoundary boundary) {
    _boundary = boundary;
    _scheduleCapture();
  }

  void _scheduleCapture() {
    if (!enabled || _disposed || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final boundary = _boundary;
      if (_disposed ||
          !enabled ||
          boundary == null ||
          !boundary.attached ||
          boundary.size.isEmpty) {
        return;
      }
      try {
        final ratio = math.min(1.5, 1024 / boundary.size.width);
        final next = boundary.toImageSync(pixelRatio: ratio);
        final previous = image;
        image = next;
        rect = MatrixUtils.transformRect(
          boundary.getTransformTo(null),
          Offset.zero & boundary.size,
        );
        imageToGlobal = boundary.getTransformTo(null)
          ..scaleByDouble(1 / ratio, 1 / ratio, 1, 1);
        revision++;
        notifyListeners();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => previous?.dispose(),
        );
      } catch (_) {
        /* Keep the previous GPU snapshot if a readback is unavailable. */
      }
    });
  }

  void invalidateGeometry() {
    refreshGeometry();
  }

  /// Keyboard and window metric changes can move the glass target before the
  /// retained wallpaper boundary is painted again. Invalidate immediately,
  /// then recapture after the new layout has settled.
  void refreshGeometry() {
    if (!enabled || _disposed) return;
    notifyListeners();
    _scheduleCapture();
  }

  @override
  void dispose() {
    _disposed = true;
    image?.dispose();
    image = null;
    super.dispose();
  }
}

class LiquidGlassInput extends StatelessWidget {
  const LiquidGlassInput({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = theme.extension<InputGlassTheme>();
    if (settings?.enabled != true) return child;
    final dark = theme.brightness == Brightness.dark;
    final parameters = settings!.parameters.copyWith();
    final opacity = parameters.opacity(dark: dark);
    final tint = (dark ? const Color(0xFF172028) : Colors.white).withValues(
      alpha: opacity,
    );
    final background =
        WallpaperReadability.maybeOf(context)?.dominantColor ??
        theme.colorScheme.surface;
    final lightText =
        BackgroundReadability.forColor(
          Color.alphaBlend(tint, background),
        ).foreground ==
        Colors.white;
    final foreground = lightText
        ? const Color(0xFFF4F7F8)
        : const Color(0xFF172028);
    final radius = BorderRadius.circular(settings.radius);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );
    final inputTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        onSurface: foreground,
        onSurfaceVariant: foreground,
      ),
      textTheme: theme.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: false,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: foreground, shadows: const []),
        floatingLabelStyle: TextStyle(color: foreground, shadows: const []),
        hintStyle: TextStyle(
          color: foreground.withValues(alpha: 0.7),
          shadows: const [],
        ),
        helperStyle: TextStyle(color: foreground, shadows: const []),
        prefixIconColor: foreground,
        suffixIconColor: foreground,
      ),
      textSelectionTheme: theme.textSelectionTheme.copyWith(
        cursorColor: foreground,
        selectionHandleColor: foreground,
        selectionColor: foreground.withValues(alpha: 0.2),
      ),
    );
    return KyantGlass(
      radius: settings.radius,
      blur: parameters.blur,
      refractionHeight: parameters.refractionHeight,
      refractionAmount: parameters.refractionAmount,
      dispersion: parameters.dispersion,
      highlight: parameters.highlight,
      pipeline: KyantPipeline.explicit,
      tint: tint,
      child: Theme(
        data: inputTheme,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground, shadows: const []),
          // Floating labels extend above the input border. Keep them inside
          // the optical surface so the glass clip cannot cut their glyphs.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: child,
          ),
        ),
      ),
    );
  }
}
