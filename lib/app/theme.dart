import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/tasks/tasks_controller.dart';
import '../models/app_theme_settings.dart';

ThemeData buildNextDdlTheme({
  Brightness brightness = Brightness.light,
  AppThemeSettings settings = const AppThemeSettings(),
}) {
  final seed = Color(settings.seedColorValue);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  final radius = BorderRadius.circular(settings.cornerRadius);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.92),
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.94),
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class NextDdlAppShell extends StatelessWidget {
  const NextDdlAppShell({
    required this.child,
    this.background = const NextDdlBackgroundLayer(),
    super.key,
  });

  final Widget background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        RepaintBoundary(child: background),
        child,
      ],
    );
  }
}

class NextDdlBackgroundLayer extends ConsumerWidget {
  const NextDdlBackgroundLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final brightness = Theme.of(context).brightness;
    return _ThemeBackground(settings: settings, brightness: brightness);
  }
}

class _ThemeBackground extends StatelessWidget {
  const _ThemeBackground({required this.settings, required this.brightness});

  final AppThemeSettings settings;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return switch (settings.backgroundMode) {
      ThemeBackgroundMode.gradient => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(settings.gradientStartColorValue),
              Color(settings.gradientEndColorValue),
            ],
          ),
        ),
      ),
      ThemeBackgroundMode.image => _ImageBackground(settings: settings),
      ThemeBackgroundMode.solid => ColoredBox(
        color: brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : Color(settings.solidBackgroundColorValue),
      ),
    };
  }
}

class BackgroundImageProviderCache {
  String? _path;
  FileImage? _provider;

  FileImage providerFor(String path) {
    if (_path != path) {
      _path = path;
      _provider = FileImage(File(path));
    }
    return _provider!;
  }
}

class _ImageBackground extends StatefulWidget {
  const _ImageBackground({required this.settings});

  final AppThemeSettings settings;

  @override
  State<_ImageBackground> createState() => _ImageBackgroundState();
}

class _ImageBackgroundState extends State<_ImageBackground> {
  static final BackgroundImageProviderCache _imageCache =
      BackgroundImageProviderCache();
  String? _precachedPath;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final path = settings.backgroundImagePath;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      return ColoredBox(color: Color(settings.solidBackgroundColorValue));
    }
    final imageProvider = _imageCache.providerFor(path);
    _precacheIfNeeded(path, imageProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final child = Transform.translate(
          offset: Offset(
            settings.imageOffsetX * constraints.maxWidth / 2,
            settings.imageOffsetY * constraints.maxHeight / 2,
          ),
          child: Transform.scale(
            scale: settings.imageScale,
            child: Transform.rotate(
              angle: settings.imageRotationDegrees * math.pi / 180,
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
          ),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: settings.imageBlurSigma,
                sigmaY: settings.imageBlurSigma,
              ),
              child: ClipRect(child: child),
            ),
            ColoredBox(
              color: Colors.black.withValues(
                alpha: settings.imageOverlayOpacity,
              ),
            ),
          ],
        );
      },
    );
  }

  void _precacheIfNeeded(String path, ImageProvider<Object> imageProvider) {
    if (_precachedPath == path) {
      return;
    }
    _precachedPath = path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      precacheImage(imageProvider, context);
    });
  }
}
