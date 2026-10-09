import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../../models/app_theme_settings.dart';
import '../../../services/theme_asset_service.dart';
import '../../tasks/tasks_controller.dart';
import '../background_image_editor_page.dart';

class ThemeSettingsCard extends ConsumerStatefulWidget {
  const ThemeSettingsCard({
    required this.settings,
    required this.enabled,
    super.key,
  });

  final AppThemeSettings settings;
  final bool enabled;

  @override
  ConsumerState<ThemeSettingsCard> createState() => _ThemeSettingsCardState();
}

class _ThemeSettingsCardState extends ConsumerState<ThemeSettingsCard> {
  bool _busy = false;
  double? _radiusPreview;
  AppThemeSettings get settings => widget.settings;
  bool get enabled => widget.enabled && !_busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.themeSettings,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _pickColor(
                          context,
                          ref,
                          l10n.themePrimaryColor,
                          Color(settings.seedColorValue),
                          (current, color) => current.copyWith(
                            seedColorValue: color.toARGB32(),
                          ),
                        )
                      : null,
                  icon: _ColorSwatch(color: Color(settings.seedColorValue)),
                  label: Text(l10n.themePrimaryColor),
                ),
                OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _pickColor(
                          context,
                          ref,
                          l10n.themeSolidBackground,
                          Color(settings.solidBackgroundColorValue),
                          (current, color) => current.copyWith(
                            backgroundMode: ThemeBackgroundMode.solid,
                            solidBackgroundColorValue: color.toARGB32(),
                          ),
                        )
                      : null,
                  icon: _ColorSwatch(
                    color: Color(settings.solidBackgroundColorValue),
                  ),
                  label: Text(l10n.themeSolidBackground),
                ),
                OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _editBackgroundImage(context, ref)
                      : null,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l10n.themeBackgroundImage),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.themeCornerRadius(
                (_radiusPreview ?? settings.cornerRadius).round(),
              ),
            ),
            Slider(
              key: const ValueKey('theme-radius'),
              value: _radiusPreview ?? settings.cornerRadius,
              min: 0,
              max: 32,
              divisions: 32,
              onChanged: enabled
                  ? (value) => setState(() => _radiusPreview = value)
                  : null,
              onChangeEnd: enabled
                  ? (value) async {
                      await _run(
                        () => ref
                            .read(tasksControllerProvider.notifier)
                            .updateThemeSettings(
                              (current) =>
                                  current.copyWith(cornerRadius: value),
                            ),
                      );
                      if (mounted) setState(() => _radiusPreview = null);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ThemeBackgroundMode>(
              segments: [
                ButtonSegment(
                  value: ThemeBackgroundMode.solid,
                  label: Text(l10n.themeBackgroundSolid),
                  icon: const Icon(Icons.format_color_fill_outlined),
                ),
                ButtonSegment(
                  value: ThemeBackgroundMode.gradient,
                  label: Text(l10n.themeBackgroundGradient),
                  icon: const Icon(Icons.gradient_outlined),
                ),
                ButtonSegment(
                  value: ThemeBackgroundMode.image,
                  label: Text(l10n.themeBackgroundImage),
                  icon: const Icon(Icons.image_outlined),
                ),
              ],
              selected: {settings.backgroundMode},
              onSelectionChanged: enabled
                  ? (values) => _run(
                      () => ref
                          .read(tasksControllerProvider.notifier)
                          .updateThemeSettings(
                            (current) =>
                                current.copyWith(backgroundMode: values.single),
                          ),
                    )
                  : null,
            ),
            if (settings.backgroundMode == ThemeBackgroundMode.gradient) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: enabled
                        ? () => _pickColor(
                            context,
                            ref,
                            l10n.themeGradientStart,
                            Color(settings.gradientStartColorValue),
                            (current, color) => current.copyWith(
                              gradientStartColorValue: color.toARGB32(),
                            ),
                          )
                        : null,
                    icon: _ColorSwatch(
                      color: Color(settings.gradientStartColorValue),
                    ),
                    label: Text(l10n.themeGradientStart),
                  ),
                  OutlinedButton.icon(
                    onPressed: enabled
                        ? () => _pickColor(
                            context,
                            ref,
                            l10n.themeGradientEnd,
                            Color(settings.gradientEndColorValue),
                            (current, color) => current.copyWith(
                              gradientEndColorValue: color.toARGB32(),
                            ),
                          )
                        : null,
                    icon: _ColorSwatch(
                      color: Color(settings.gradientEndColorValue),
                    ),
                    label: Text(l10n.themeGradientEnd),
                  ),
                ],
              ),
            ],
            if (settings.backgroundMode == ThemeBackgroundMode.image) ...[
              if (settings.backgroundImagePath != null)
                TextButton.icon(
                  onPressed: enabled ? () => _editCurrentImage() : null,
                  icon: const Icon(Icons.crop_rotate),
                  label: Text(l10n.themeEditBackgroundImage),
                ),
              const SizedBox(height: 12),
              Text(
                settings.backgroundImagePath == null
                    ? l10n.themeNoBackgroundImage
                    : l10n.themeBackgroundImageReady,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (settings.backgroundImageHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.themeRecentBackgrounds,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: settings.backgroundImageHistory.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = settings.backgroundImageHistory[index];
                    final selected =
                        settings.backgroundMode == ThemeBackgroundMode.image &&
                        settings.backgroundImagePath == preset.path;
                    final label = selected
                        ? l10n.themeBackgroundSelected
                        : l10n.themeUseRecentBackground(index + 1);
                    return Semantics(
                      selected: selected,
                      button: true,
                      label: label,
                      child: Tooltip(
                        message: label,
                        child: InkWell(
                          key: ValueKey('recent-background-${preset.path}'),
                          onTap: enabled ? () => _restoreImage(preset) : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 96,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                width: selected ? 3 : 1,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(preset.path),
                                    fit: BoxFit.cover,
                                    cacheWidth: 240,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                  if (selected)
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    String title,
    Color initial,
    AppThemeSettings Function(AppThemeSettings current, Color color) builder,
  ) async {
    Color selected = initial;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: selected,
            onColorChanged: (color) => selected = color,
            pickersEnabled: const {
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
              ColorPickerType.wheel: true,
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => ref
            .read(tasksControllerProvider.notifier)
            .updateThemeSettings((current) => builder(current, selected)),
      );
    }
  }

  Future<void> _editBackgroundImage(BuildContext context, WidgetRef ref) async {
    await _run(() async {
      final service = ref.read(themeAssetServiceProvider);
      final copiedPath = await service.pickAndCopyBackgroundImage();
      if (copiedPath == null) return;
      var saved = false;
      try {
        if (!context.mounted) return;
        final edited = await Navigator.of(context).push<AppThemeSettings>(
          MaterialPageRoute(
            builder: (_) => BackgroundImageEditorPage(
              initial: ref
                  .read(themeSettingsProvider)
                  .copyWith(
                    backgroundMode: ThemeBackgroundMode.image,
                    backgroundImagePath: copiedPath,
                    imageScale: 1,
                    imageOffsetX: 0,
                    imageOffsetY: 0,
                    imageRotationQuarterTurns: 0,
                    imageRotationDegrees: 0,
                  ),
            ),
          ),
        );
        if (edited == null || !mounted) return;
        await ref
            .read(tasksControllerProvider.notifier)
            .updateThemeSettings(
              BackgroundImagePreset.fromTheme(edited).applyTo,
            );
        saved = true;
      } finally {
        if (!saved) await service.deleteBackgroundImage(copiedPath);
      }
    });
  }

  Future<void> _restoreImage(BackgroundImagePreset preset) => _run(() async {
    if (!await File(preset.path).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.themeBackgroundUnavailable,
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    await ref
        .read(tasksControllerProvider.notifier)
        .updateThemeSettings(preset.applyTo);
  });

  Future<void> _editCurrentImage() => _run(() async {
    final current = ref.read(themeSettingsProvider);
    final edited = await Navigator.of(context).push<AppThemeSettings>(
      MaterialPageRoute(
        builder: (_) => BackgroundImageEditorPage(initial: current),
      ),
    );
    if (edited == null || !mounted) return;
    await ref
        .read(tasksControllerProvider.notifier)
        .updateThemeSettings(BackgroundImagePreset.fromTheme(edited).applyTo);
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.themeSaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
