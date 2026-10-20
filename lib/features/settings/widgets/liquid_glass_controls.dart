import 'package:flutter/material.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../../app/liquid_glass_input.dart';
import '../../../models/app_theme_settings.dart';
import '../../../models/liquid_glass_settings.dart';

class LiquidGlassControls extends StatefulWidget {
  const LiquidGlassControls({
    required this.settings,
    required this.enabled,
    required this.onSave,
    required this.onReset,
    super.key,
  });
  final AppThemeSettings settings;
  final bool enabled;
  final Future<void> Function(LiquidGlassParameter, double) onSave;
  final Future<void> Function() onReset;

  @override
  State<LiquidGlassControls> createState() => _LiquidGlassControlsState();
}

class _LiquidGlassControlsState extends State<LiquidGlassControls> {
  LiquidGlassSettings? _draft;
  bool _saving = false;
  bool get enabled => widget.enabled && !_saving;

  Future<void> _save(LiquidGlassParameter parameter, double value) async {
    if (!enabled) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(parameter, value);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _draft = null;
        });
      }
    }
  }

  Future<void> _reset() async {
    if (!enabled) return;
    setState(() {
      _saving = true;
      _draft = const LiquidGlassSettings();
    });
    try {
      await widget.onReset();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _draft = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final parameters = _draft ?? widget.settings.liquidGlassSettings;
    final glassTheme = InputGlassTheme(
      enabled: true,
      radius: widget.settings.cornerRadius,
      parameters: parameters,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Theme(
          data: theme.copyWith(
            extensions: [
              ...theme.extensions.values.where(
                (extension) => extension is! InputGlassTheme,
              ),
              glassTheme,
            ],
          ),
          child: LiquidGlassInput(
            key: const ValueKey('theme-glass-preview'),
            child: TextField(
              readOnly: true,
              canRequestFocus: false,
              enableInteractiveSelection: false,
              decoration: InputDecoration(
                labelText: l.themeGlassPreview,
                hintText: l.themeGlassPreviewText,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final parameter in LiquidGlassParameter.values) ...[
          Row(
            children: [
              Expanded(child: Text(_label(l, parameter))),
              const SizedBox(width: 12),
              Text(
                _format(
                  parameter,
                  parameters.valueFor(
                    parameter,
                    dark: theme.brightness == Brightness.dark,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            key: ValueKey('theme-glass-${parameter.name}'),
            value: parameters.valueFor(
              parameter,
              dark: theme.brightness == Brightness.dark,
            ),
            min: parameter.min,
            max: parameter.max,
            divisions: parameter.divisions,
            label: _format(
              parameter,
              parameters.valueFor(
                parameter,
                dark: theme.brightness == Brightness.dark,
              ),
            ),
            semanticFormatterCallback: (value) =>
                '${_label(l, parameter)}: ${_format(parameter, value)}',
            onChanged: enabled
                ? (value) => setState(
                    () => _draft = parameters.withValue(parameter, value),
                  )
                : null,
            onChangeEnd: enabled ? (value) => _save(parameter, value) : null,
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('theme-glass-reset'),
            onPressed: enabled ? _reset : null,
            icon: const Icon(Icons.restart_alt),
            label: Text(l.themeGlassReset),
          ),
        ),
        const Divider(),
      ],
    );
  }

  String _format(LiquidGlassParameter parameter, double value) =>
      parameter.isPercent
      ? '${(value * 100).round()}%'
      : value.toStringAsFixed(1);

  String _label(AppLocalizations l, LiquidGlassParameter parameter) =>
      switch (parameter) {
        LiquidGlassParameter.blur => l.themeGlassBlur,
        LiquidGlassParameter.refractionHeight => l.themeGlassRefractionHeight,
        LiquidGlassParameter.refractionAmount => l.themeGlassRefractionAmount,
        LiquidGlassParameter.dispersion => l.themeGlassDispersion,
        LiquidGlassParameter.tintOpacity => l.themeGlassTintOpacity,
        LiquidGlassParameter.highlight => l.themeGlassHighlight,
      };
}
