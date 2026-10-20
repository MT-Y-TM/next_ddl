import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
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
            onPointerScroll: (event) {
              if (event.scrollDelta.dy == 0) return;
              final factor = event.scrollDelta.dy < 0 ? 1.08 : 0.92;
              setState(
                () => _settings = _settings.copyWith(
                  imageScale: _settings.imageScale * factor,
                ),
              );
            },
            onPointerPan: (delta, size) {
              final width = size.width <= 0 ? 1.0 : size.width;
              final height = size.height <= 0 ? 1.0 : size.height;
              setState(
                () => _settings = _settings.copyWith(
                  imageOffsetX: _settings.imageOffsetX + delta.dx / (width / 2),
                  imageOffsetY: _settings.imageOffsetY + delta.dy / (height / 2),
                ),
              );
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

class _GesturePreview extends StatefulWidget {
  const _GesturePreview({
    required this.settings,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onPointerScroll,
    required this.onPointerPan,
  });

  final AppThemeSettings settings;
  final VoidCallback onScaleStart;
  final void Function(ScaleUpdateDetails details, Size size) onScaleUpdate;
  final ValueChanged<PointerScrollEvent> onPointerScroll;
  final void Function(Offset delta, Size size) onPointerPan;

  @override
  State<_GesturePreview> createState() => _GesturePreviewState();
}

class _GesturePreviewState extends State<_GesturePreview> {
  Offset? _mousePosition;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.mouse &&
                event.buttons & kPrimaryMouseButton != 0) {
              _mousePosition = event.position;
            }
          },
          onPointerMove: (event) {
            if (_mousePosition == null ||
                event.kind != PointerDeviceKind.mouse ||
                event.buttons & kPrimaryMouseButton == 0) {
              return;
            }
            final delta = event.position - _mousePosition!;
            _mousePosition = event.position;
            widget.onPointerPan(delta, size);
          },
          onPointerUp: (_) => _mousePosition = null,
          onPointerCancel: (_) => _mousePosition = null,
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) widget.onPointerScroll(event);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => widget.onScaleStart(),
            onScaleUpdate: (details) => widget.onScaleUpdate(details, size),
            child: _ImagePreview(settings: widget.settings),
          ),
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
                  // Start with the whole source image visible. Users can then
                  // zoom and pan to choose any crop rather than guessing what
                  // was hidden by an initial cover fit.
                  fit: BoxFit.contain,
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
              label: l10n.themeImageRotation,
              value: settings.imageRotationDegrees,
              min: 0,
              max: 360,
              divisions: 360,
              valueLabel: (value) => '${value.round()}°',
              onChanged: (value) =>
                  onChanged(settings.copyWith(imageRotationDegrees: value)),
            ),
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
    this.divisions,
    this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double value)? valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel?.call(value) ?? value.toStringAsFixed(2)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
