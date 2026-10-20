import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/background_readability.dart';

class WallpaperReadability extends InheritedWidget {
  const WallpaperReadability({
    required this.value,
    required super.child,
    super.key,
  });

  final BackgroundReadability value;

  static BackgroundReadability? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WallpaperReadability>()?.value;

  @override
  bool updateShouldNotify(WallpaperReadability oldWidget) =>
      oldWidget.value.foreground != value.foreground ||
      oldWidget.value.needsHalo != value.needsHalo;
}

/// Only opt transparent content into this theme. Cards, chips, filled buttons,
/// app bars and dialogs keep their original surface/foreground color pairs.
class WallpaperRegion extends StatelessWidget {
  const WallpaperRegion({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final readability = WallpaperReadability.maybeOf(context);
    if (readability == null) return child;
    final base = Theme.of(context);
    final foreground = readability.foreground;
    TextStyle readable(TextStyle? style) => (style ?? const TextStyle())
        .copyWith(color: foreground, shadows: readability.shadows);
    final textTheme = base.textTheme.copyWith(
      displayLarge: readable(base.textTheme.displayLarge),
      displayMedium: readable(base.textTheme.displayMedium),
      displaySmall: readable(base.textTheme.displaySmall),
      headlineLarge: readable(base.textTheme.headlineLarge),
      headlineMedium: readable(base.textTheme.headlineMedium),
      headlineSmall: readable(base.textTheme.headlineSmall),
      titleLarge: readable(base.textTheme.titleLarge),
      titleMedium: readable(base.textTheme.titleMedium),
      titleSmall: readable(base.textTheme.titleSmall),
      bodyLarge: readable(base.textTheme.bodyLarge),
      bodyMedium: readable(base.textTheme.bodyMedium),
      bodySmall: readable(base.textTheme.bodySmall),
      labelLarge: readable(base.textTheme.labelLarge),
      labelMedium: readable(base.textTheme.labelMedium),
      labelSmall: readable(base.textTheme.labelSmall),
    );
    final border = BorderSide(color: foreground.withValues(alpha: 0.8));
    final originalInput = base.inputDecorationTheme;
    return Theme(
      data: base.copyWith(
        textTheme: textTheme,
        colorScheme: base.colorScheme.copyWith(
          onSurface: foreground,
          onSurfaceVariant: foreground,
        ),
        iconTheme: base.iconTheme.copyWith(color: foreground),
        textSelectionTheme: base.textSelectionTheme.copyWith(
          cursorColor: foreground,
          selectionHandleColor: foreground,
          selectionColor: foreground.withValues(alpha: 0.25),
        ),
        listTileTheme: base.listTileTheme.copyWith(
          textColor: foreground,
          iconColor: foreground,
          titleTextStyle: readable(base.textTheme.bodyLarge),
          subtitleTextStyle: readable(base.textTheme.bodyMedium),
          leadingAndTrailingTextStyle: readable(base.textTheme.bodyMedium),
        ),
        inputDecorationTheme: originalInput.copyWith(
          labelStyle: readable(originalInput.labelStyle),
          floatingLabelStyle: readable(originalInput.floatingLabelStyle),
          hintStyle: readable(originalInput.hintStyle),
          helperStyle: readable(originalInput.helperStyle),
          prefixIconColor: foreground,
          suffixIconColor: foreground,
          enabledBorder:
              (originalInput.enabledBorder ??
                      originalInput.border ??
                      const OutlineInputBorder())
                  .copyWith(borderSide: border),
          focusedBorder:
              (originalInput.focusedBorder ??
                      originalInput.border ??
                      const OutlineInputBorder())
                  .copyWith(borderSide: border.copyWith(width: 2)),
        ),
        checkboxTheme: base.checkboxTheme.copyWith(side: border),
        textButtonTheme: TextButtonThemeData(
          style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => foreground.withValues(
                alpha: states.contains(WidgetState.disabled) ? 0.5 : 1,
              ),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (base.outlinedButtonTheme.style ?? const ButtonStyle())
              .copyWith(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => foreground.withValues(
                    alpha: states.contains(WidgetState.disabled) ? 0.5 : 1,
                  ),
                ),
                side: WidgetStatePropertyAll(border),
              ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground, shadows: readability.shadows),
        child: child,
      ),
    );
  }
}

class WallpaperText extends StatelessWidget {
  const WallpaperText(
    this.data, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final readability = WallpaperReadability.maybeOf(context);
    return Text(
      data,
      style: readability == null
          ? style
          : (style ?? const TextStyle()).copyWith(
              color: readability.foreground,
              shadows: readability.shadows,
            ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class BackgroundReadabilityHost extends StatefulWidget {
  const BackgroundReadabilityHost({
    required this.background,
    required this.child,
    super.key,
  });
  final Widget background;
  final Widget child;

  @override
  State<BackgroundReadabilityHost> createState() =>
      _BackgroundReadabilityHostState();
}

class _BackgroundReadabilityHostState extends State<BackgroundReadabilityHost> {
  BackgroundReadability? _value;
  RenderRepaintBoundary? _boundary;
  var _revision = 0;
  var _scheduled = false;
  var _capturing = false;

  void _painted(RenderRepaintBoundary boundary) {
    _boundary = boundary;
    _revision++;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && !_capturing) unawaited(_capture());
    });
  }

  Future<void> _capture() async {
    final boundary = _boundary;
    if (boundary == null || !boundary.attached || boundary.size.isEmpty) return;
    final revision = _revision;
    _capturing = true;
    ui.Image? image;
    try {
      // At most 64x64 pixels, independent of phone DPI and original image size.
      image = await boundary.toImage(
        pixelRatio: math.min(1, 64 / boundary.size.longestSide),
      );
      final bytes = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (bytes == null || !mounted || revision != _revision) return;
      final result = analyzeBackgroundPixels(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      if (_value?.foreground != result.foreground ||
          _value?.needsHalo != result.needsHalo) {
        setState(() => _value = result);
      } else {
        _value = result;
      }
    } catch (_) {
      // Keep the last readable state if a renderer cannot provide a readback.
    } finally {
      image?.dispose();
      _capturing = false;
      if (mounted && revision != _revision) {
        _schedule();
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    alignment: Alignment.topLeft,
    children: [
      _ReadabilityBoundary(onPaint: _painted, child: widget.background),
      WallpaperReadability(
        value:
            _value ??
            BackgroundReadability.forColor(
              Theme.of(context).colorScheme.surface,
            ),
        child: widget.child,
      ),
    ],
  );
}

class _ReadabilityBoundary extends SingleChildRenderObjectWidget {
  const _ReadabilityBoundary({required this.onPaint, required super.child});
  final ValueChanged<RenderRepaintBoundary> onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ReadabilityRenderBoundary(onPaint);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ReadabilityRenderBoundary renderObject,
  ) => renderObject.onPaint = onPaint;
}

class _ReadabilityRenderBoundary extends RenderRepaintBoundary {
  _ReadabilityRenderBoundary(this.onPaint);
  ValueChanged<RenderRepaintBoundary> onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint(this);
  }
}
