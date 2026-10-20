enum LiquidGlassParameter {
  blur(0, 20, 40),
  refractionHeight(0, 40, 80),
  refractionAmount(0, 30, 60),
  dispersion(0, 1, 100),
  tintOpacity(0, 1, 100),
  highlight(0, 1, 100);

  const LiquidGlassParameter(this.min, this.max, this.divisions);
  final double min, max;
  final int divisions;
  bool get isPercent => max == 1;
}

class LiquidGlassSettings {
  const LiquidGlassSettings({
    this.blur = 6,
    this.refractionHeight = 10,
    this.refractionAmount = 5,
    this.dispersion = 0.08,
    this.tintOpacity,
    this.highlight = 0.45,
  });

  final double blur, refractionHeight, refractionAmount, dispersion, highlight;

  // Null retains the 1.2.10 defaults for light (58%) and dark (72%) themes.
  final double? tintOpacity;

  double opacity({required bool dark}) => tintOpacity ?? (dark ? 0.72 : 0.58);

  double valueFor(LiquidGlassParameter parameter, {required bool dark}) =>
      switch (parameter) {
        LiquidGlassParameter.blur => blur,
        LiquidGlassParameter.refractionHeight => refractionHeight,
        LiquidGlassParameter.refractionAmount => refractionAmount,
        LiquidGlassParameter.dispersion => dispersion,
        LiquidGlassParameter.tintOpacity => opacity(dark: dark),
        LiquidGlassParameter.highlight => highlight,
      };

  LiquidGlassSettings withValue(
    LiquidGlassParameter parameter,
    double value,
  ) => switch (parameter) {
    LiquidGlassParameter.blur => copyWith(blur: value),
    LiquidGlassParameter.refractionHeight => copyWith(refractionHeight: value),
    LiquidGlassParameter.refractionAmount => copyWith(refractionAmount: value),
    LiquidGlassParameter.dispersion => copyWith(dispersion: value),
    LiquidGlassParameter.tintOpacity => copyWith(tintOpacity: value),
    LiquidGlassParameter.highlight => copyWith(highlight: value),
  };

  LiquidGlassSettings copyWith({
    double? blur,
    double? refractionHeight,
    double? refractionAmount,
    double? dispersion,
    Object? tintOpacity = _unset,
    double? highlight,
  }) => LiquidGlassSettings(
    blur: _bounded(blur ?? this.blur, LiquidGlassParameter.blur, 6),
    refractionHeight: _bounded(
      refractionHeight ?? this.refractionHeight,
      LiquidGlassParameter.refractionHeight,
      10,
    ),
    refractionAmount: _bounded(
      refractionAmount ?? this.refractionAmount,
      LiquidGlassParameter.refractionAmount,
      5,
    ),
    dispersion: _bounded(
      dispersion ?? this.dispersion,
      LiquidGlassParameter.dispersion,
      0.08,
    ),
    tintOpacity: _optionalOpacity(
      identical(tintOpacity, _unset) ? this.tintOpacity : tintOpacity,
    ),
    highlight: _bounded(
      highlight ?? this.highlight,
      LiquidGlassParameter.highlight,
      0.45,
    ),
  );

  Map<String, dynamic> toJson() => {
    'blur': blur,
    'refractionHeight': refractionHeight,
    'refractionAmount': refractionAmount,
    'dispersion': dispersion,
    'tintOpacity': tintOpacity,
    'highlight': highlight,
  };

  factory LiquidGlassSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LiquidGlassSettings();
    double read(String key, double fallback) =>
        (json[key] is num) ? (json[key] as num).toDouble() : fallback;
    return const LiquidGlassSettings().copyWith(
      blur: read('blur', 6),
      refractionHeight: read('refractionHeight', 10),
      refractionAmount: read('refractionAmount', 5),
      dispersion: read('dispersion', 0.08),
      tintOpacity: _optionalOpacity(json['tintOpacity']),
      highlight: read('highlight', 0.45),
    );
  }

  static double _bounded(
    double value,
    LiquidGlassParameter p,
    double fallback,
  ) => value.isFinite ? value.clamp(p.min, p.max).toDouble() : fallback;

  static double? _optionalOpacity(Object? value) =>
      value is num && value.isFinite
      ? value.toDouble().clamp(0, 1).toDouble()
      : null;

  static LiquidGlassSettings lerp(
    LiquidGlassSettings a,
    LiquidGlassSettings b,
    double t,
  ) {
    double between(double a, double b) => a + (b - a) * t;
    return LiquidGlassSettings(
      blur: between(a.blur, b.blur),
      refractionHeight: between(a.refractionHeight, b.refractionHeight),
      refractionAmount: between(a.refractionAmount, b.refractionAmount),
      dispersion: between(a.dispersion, b.dispersion),
      tintOpacity: a.tintOpacity == null || b.tintOpacity == null
          ? (t < 0.5 ? a.tintOpacity : b.tintOpacity)
          : between(a.tintOpacity!, b.tintOpacity!),
      highlight: between(a.highlight, b.highlight),
    );
  }
}

const _unset = Object();
