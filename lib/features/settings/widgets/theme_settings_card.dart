import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../../models/app_theme_settings.dart';
import '../../../services/theme_asset_service.dart';
import '../../tasks/tasks_controller.dart';
import '../background_image_editor_page.dart';

class ThemeSettingsCard extends ConsumerWidget {
  const ThemeSettingsCard({
    required this.settings,
    required this.enabled,
    super.key,
  });

  final AppThemeSettings settings;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          (color) => settings.copyWith(
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
                          (color) => settings.copyWith(
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
            Text(l10n.themeCornerRadius(settings.cornerRadius.round())),
            Slider(
              value: settings.cornerRadius,
              min: 0,
              max: 32,
              divisions: 32,
              onChanged: enabled
                  ? (value) => ref
                        .read(tasksControllerProvider.notifier)
                        .setThemeSettings(
                          settings.copyWith(cornerRadius: value),
                        )
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
                  ? (values) => ref
                        .read(tasksControllerProvider.notifier)
                        .setThemeSettings(
                          settings.copyWith(backgroundMode: values.single),
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
                            (color) => settings.copyWith(
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
                            (color) => settings.copyWith(
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
              const SizedBox(height: 12),
              Text(
                settings.backgroundImagePath == null
                    ? l10n.themeNoBackgroundImage
                    : l10n.themeBackgroundImageReady,
                style: Theme.of(context).textTheme.bodySmall,
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
    AppThemeSettings Function(Color color) builder,
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
    if (confirmed == true) {
      await ref
          .read(tasksControllerProvider.notifier)
          .setThemeSettings(builder(selected));
    }
  }

  Future<void> _editBackgroundImage(BuildContext context, WidgetRef ref) async {
    final service = ref.read(themeAssetServiceProvider);
    final copiedPath = await service.pickAndCopyBackgroundImage(
      oldPath: settings.backgroundImagePath,
    );
    if (copiedPath == null || !context.mounted) {
      return;
    }
    final edited = await Navigator.of(context).push<AppThemeSettings>(
      MaterialPageRoute(
        builder: (dialogContext) => BackgroundImageEditorPage(
          initial: settings.copyWith(
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
    if (edited == null) {
      await service.deleteBackgroundImage(copiedPath);
      return;
    }
    await ref.read(tasksControllerProvider.notifier).setThemeSettings(edited);
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
