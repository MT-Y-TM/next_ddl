enum AiProtocol { chatCompletions, responses, anthropicMessages }

class AppPredictionSettings {
  const AppPredictionSettings({
    this.enabled = false,
    this.autoApply = true,
    this.aiEnabled = false,
    this.aiProtocol = AiProtocol.chatCompletions,
    this.baseUrl = '',
    this.model = '',
    this.stepByStep = false,
    this.customPrompt = '',
  });

  final bool enabled;
  final bool autoApply;
  final bool aiEnabled;
  final AiProtocol aiProtocol;
  final String baseUrl;
  final String model;
  final bool stepByStep;
  final String customPrompt;

  AppPredictionSettings copyWith({
    bool? enabled,
    bool? autoApply,
    bool? aiEnabled,
    AiProtocol? aiProtocol,
    String? baseUrl,
    String? model,
    bool? stepByStep,
    String? customPrompt,
  }) => AppPredictionSettings(
    enabled: enabled ?? this.enabled,
    autoApply: autoApply ?? this.autoApply,
    aiEnabled: aiEnabled ?? this.aiEnabled,
    aiProtocol: aiProtocol ?? this.aiProtocol,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    stepByStep: stepByStep ?? this.stepByStep,
    customPrompt: customPrompt ?? this.customPrompt,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'autoApply': autoApply,
    'aiEnabled': aiEnabled,
    'aiProtocol': aiProtocol.name,
    'baseUrl': baseUrl,
    'model': model,
    'stepByStep': stepByStep,
    'customPrompt': customPrompt,
  };

  factory AppPredictionSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppPredictionSettings();
    final protocol = AiProtocol.values.where(
      (item) => item.name == json['aiProtocol'],
    );
    return AppPredictionSettings(
      enabled: json['enabled'] as bool? ?? false,
      autoApply: json['autoApply'] as bool? ?? true,
      aiEnabled: json['aiEnabled'] as bool? ?? false,
      aiProtocol: protocol.isEmpty
          ? AiProtocol.chatCompletions
          : protocol.first,
      baseUrl: json['baseUrl'] as String? ?? '',
      model: json['model'] as String? ?? '',
      stepByStep: json['stepByStep'] as bool? ?? false,
      customPrompt: json['customPrompt'] as String? ?? '',
    );
  }
}
