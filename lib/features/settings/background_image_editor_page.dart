import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../models/app_theme_settings.dart';

class BackgroundImageEditorPage extends StatefulWidget {
  const BackgroundImageEditorPage({required this.initial, super.key});

  final AppThemeSettings initial;

  @override
  State<BackgroundImageEditorPage> createState() =>
      _BackgroundImageEditorPageState();
}

class _BackgroundImageEditorPageState extends State<BackgroundImageEditorPage> {
  late AppThemeSettings _settings = widget.initial;
  late double _gestureStartScale;
  late double _gestureStartRotationDegrees;

  @override
  void initState() {
    super.initState();
    _gestureStartScale = _settings.imageScale;
    _gestureStartRotationDegrees = _settings.imageRotationDegrees;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.themeEditBackgroundImage),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.78),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _GesturePreview(
            settings: _settings,
            onScaleStart: () {
              _gestureStartScale = _settings.imageScale;
              _gestureStartRotationDegrees = _settings.imageRotationDegrees;
            },
            onScaleUpdate: (details, size) {
              final width = size.width <= 0 ? 1.0 : size.width;
              final height = size.height <= 0 ? 1.0 : size.height;
              setState(() {
                _settings = _settings.copyWith(
                  imageScale: _gestureStartScale * details.scale,
                  imageRotationDegrees:
                      _gestureStartRotationDegrees +
                      details.rotation * 180 / math.pi,
                  imageOffsetX:
                      _settings.imageOffsetX +
                      details.focalPointDelta.dx / (width / 2),
                  imageOffsetY:
                      _settings.imageOffsetY +
                      details.focalPointDelta.dy / (height / 2),
                );
              });
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _EditorControls(
              settings: _settings,
              onChanged: (value) => setState(() => _settings = value),
              onReset: _resetImageParameters,
              onCancel: () => Navigator.of(context).pop(),
              onSave: () => Navigator.of(context).pop(_settings),
            ),
          ),
        ],
      ),
    );
  }

  void _resetImageParameters() {
    final defaults = AppThemeSettings.defaults();
    setState(() {
      _settings = _settings.copyWith(
        imageScale: defaults.imageScale,
        imageOffsetX: defaults.imageOffsetX,
        imageOffsetY: defaults.imageOffsetY,
        imageRotationQuarterTurns: defaults.imageRotationQuarterTurns,
        imageRotationDegrees: defaults.imageRotationDegrees,
        imageOverlayOpacity: defaults.imageOverlayOpacity,
        imageBlurSigma: defaults.imageBlurSigma,
      );
    });
  }
}

class _GesturePreview extends StatelessWidget {
  const _GesturePreview({
    required this.settings,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final AppThemeSettings settings;
  final VoidCallback onScaleStart;
  final void Function(ScaleUpdateDetails details, Size size) onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => onScaleStart(),
          onScaleUpdate: (details) => onScaleUpdate(details, size),
          child: _ImagePreview(settings: settings),
        );
      },
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.settings});

  final AppThemeSettings settings;

  @override
  Widget build(BuildContext context) {
    final path = settings.backgroundImagePath;
    final hasImage = path != null && path.isNotEmpty && File(path).existsSync();
    final image = hasImage
        ? Transform.translate(
            offset: Offset(
              settings.imageOffsetX * MediaQuery.sizeOf(context).width / 2,
              settings.imageOffsetY * MediaQuery.sizeOf(context).height / 2,
            ),
            child: Transform.scale(
              scale: settings.imageScale,
              child: Transform.rotate(
                angle: settings.imageRotationDegrees * math.pi / 180,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          )
        : Center(
            child: Text(
              AppLocalizations.of(context)!.themeNoBackgroundImage,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).colorScheme.surface),
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: settings.imageBlurSigma,
            sigmaY: settings.imageBlurSigma,
          ),
          child: ClipRect(child: image),
        ),
        ColoredBox(
          color: Colors.black.withValues(alpha: settings.imageOverlayOpacity),
        ),
      ],
    );
  }
}

class _EditorControls extends StatelessWidget {
  const _EditorControls({
    required this.settings,
    required this.onChanged,
    required this.onReset,
    required this.onCancel,
    required this.onSave,
  });

  final AppThemeSettings settings;
  final ValueChanged<AppThemeSettings> onChanged;
  final VoidCallback onReset;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledSlider(
              label: l10n.themeImageOverlay,
              value: settings.imageOverlayOpacity,
              min: 0,
              max: 0.85,
              onChanged: (value) =>
                  onChanged(settings.copyWith(imageOverlayOpacity: value)),
            ),
            _LabeledSlider(
              label: l10n.themeImageBlur,
              value: settings.imageBlurSigma,
              min: 0,
              max: 20,
              onChanged: (value) =>
                  onChanged(settings.copyWith(imageBlurSigma: value)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onChanged(
                    settings.copyWith(
                      imageRotationQuarterTurns:
                          settings.imageRotationQuarterTurns + 1,
                      imageRotationDegrees: settings.imageRotationDegrees + 90,
                    ),
                  ),
                  icon: const Icon(Icons.rotate_90_degrees_ccw_outlined),
                  label: Text(l10n.themeRotateImage),
                ),
                OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: Text(l10n.themeResetImage),
                ),
                TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
                FilledButton(
                  onPressed: onSave,
                  child: Text(l10n.themeSaveBackground),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(value.toStringAsFixed(2)),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
