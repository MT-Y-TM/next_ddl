enum ThemeBackgroundMode {
  solid('solid'),
  gradient('gradient'),
  image('image');

  const ThemeBackgroundMode(this.value);

  final String value;

  static ThemeBackgroundMode fromValue(String? value) {
    return ThemeBackgroundMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ThemeBackgroundMode.solid,
    );
  }
}

class AppThemeSettings {
  const AppThemeSettings({
    this.seedColorValue = 0xFF0E7490,
    this.cornerRadius = 8,
    this.backgroundMode = ThemeBackgroundMode.solid,
    this.solidBackgroundColorValue = 0xFFF4F7F8,
    this.gradientStartColorValue = 0xFFF4F7F8,
    this.gradientEndColorValue = 0xFFE0F2FE,
    this.backgroundImagePath,
    this.imageScale = 1,
    this.imageOffsetX = 0,
    this.imageOffsetY = 0,
    this.imageRotationQuarterTurns = 0,
    this.imageOverlayOpacity = 0.35,
    this.imageBlurSigma = 0,
  });

  final int seedColorValue;
  final double cornerRadius;
  final ThemeBackgroundMode backgroundMode;
  final int solidBackgroundColorValue;
  final int gradientStartColorValue;
  final int gradientEndColorValue;
  final String? backgroundImagePath;
  final double imageScale;
  final double imageOffsetX;
  final double imageOffsetY;
  final int imageRotationQuarterTurns;
  final double imageOverlayOpacity;
  final double imageBlurSigma;

  factory AppThemeSettings.defaults() {
    return const AppThemeSettings();
  }

  AppThemeSettings copyWith({
    int? seedColorValue,
    double? cornerRadius,
    ThemeBackgroundMode? backgroundMode,
    int? solidBackgroundColorValue,
    int? gradientStartColorValue,
    int? gradientEndColorValue,
    Object? backgroundImagePath = _unset,
    double? imageScale,
    double? imageOffsetX,
    double? imageOffsetY,
    int? imageRotationQuarterTurns,
    double? imageOverlayOpacity,
    double? imageBlurSigma,
  }) {
    return AppThemeSettings(
      seedColorValue: seedColorValue ?? this.seedColorValue,
      cornerRadius: (cornerRadius ?? this.cornerRadius).clamp(0, 32).toDouble(),
      backgroundMode: backgroundMode ?? this.backgroundMode,
      solidBackgroundColorValue:
          solidBackgroundColorValue ?? this.solidBackgroundColorValue,
      gradientStartColorValue:
          gradientStartColorValue ?? this.gradientStartColorValue,
      gradientEndColorValue: gradientEndColorValue ?? this.gradientEndColorValue,
      backgroundImagePath: identical(backgroundImagePath, _unset)
          ? this.backgroundImagePath
          : backgroundImagePath as String?,
      imageScale: (imageScale ?? this.imageScale).clamp(0.5, 3).toDouble(),
      imageOffsetX: (imageOffsetX ?? this.imageOffsetX).clamp(-1, 1).toDouble(),
      imageOffsetY: (imageOffsetY ?? this.imageOffsetY).clamp(-1, 1).toDouble(),
      imageRotationQuarterTurns:
          (imageRotationQuarterTurns ?? this.imageRotationQuarterTurns) % 4,
      imageOverlayOpacity:
          (imageOverlayOpacity ?? this.imageOverlayOpacity).clamp(0, 0.85).toDouble(),
      imageBlurSigma: (imageBlurSigma ?? this.imageBlurSigma).clamp(0, 20).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'seedColorValue': seedColorValue,
        'cornerRadius': cornerRadius,
        'backgroundMode': backgroundMode.value,
        'solidBackgroundColorValue': solidBackgroundColorValue,
        'gradientStartColorValue': gradientStartColorValue,
        'gradientEndColorValue': gradientEndColorValue,
        'backgroundImagePath': backgroundImagePath,
        'imageScale': imageScale,
        'imageOffsetX': imageOffsetX,
        'imageOffsetY': imageOffsetY,
        'imageRotationQuarterTurns': imageRotationQuarterTurns,
        'imageOverlayOpacity': imageOverlayOpacity,
        'imageBlurSigma': imageBlurSigma,
      };

  factory AppThemeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AppThemeSettings.defaults();
    }
    final defaults = AppThemeSettings.defaults();
    return AppThemeSettings(
      seedColorValue:
          (json['seedColorValue'] as num?)?.toInt() ?? defaults.seedColorValue,
      cornerRadius:
          ((json['cornerRadius'] as num?)?.toDouble() ?? defaults.cornerRadius)
              .clamp(0, 32)
              .toDouble(),
      backgroundMode:
          ThemeBackgroundMode.fromValue(json['backgroundMode'] as String?),
      solidBackgroundColorValue:
          (json['solidBackgroundColorValue'] as num?)?.toInt() ??
              defaults.solidBackgroundColorValue,
      gradientStartColorValue:
          (json['gradientStartColorValue'] as num?)?.toInt() ??
              defaults.gradientStartColorValue,
      gradientEndColorValue:
          (json['gradientEndColorValue'] as num?)?.toInt() ??
              defaults.gradientEndColorValue,
      backgroundImagePath: json['backgroundImagePath'] as String?,
      imageScale: ((json['imageScale'] as num?)?.toDouble() ?? defaults.imageScale)
          .clamp(0.5, 3)
          .toDouble(),
      imageOffsetX:
          ((json['imageOffsetX'] as num?)?.toDouble() ?? defaults.imageOffsetX)
              .clamp(-1, 1)
              .toDouble(),
      imageOffsetY:
          ((json['imageOffsetY'] as num?)?.toDouble() ?? defaults.imageOffsetY)
              .clamp(-1, 1)
              .toDouble(),
      imageRotationQuarterTurns:
          ((json['imageRotationQuarterTurns'] as num?)?.toInt() ??
                  defaults.imageRotationQuarterTurns) %
              4,
      imageOverlayOpacity:
          ((json['imageOverlayOpacity'] as num?)?.toDouble() ??
                  defaults.imageOverlayOpacity)
              .clamp(0, 0.85)
              .toDouble(),
      imageBlurSigma:
          ((json['imageBlurSigma'] as num?)?.toDouble() ?? defaults.imageBlurSigma)
              .clamp(0, 20)
              .toDouble(),
    );
  }
}

const Object _unset = Object();
