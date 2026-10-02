import 'package:flutter/widgets.dart';

class PredictionUiStrings {
  PredictionUiStrings(BuildContext context)
    : _language = Localizations.localeOf(context).languageCode;
  final String _language;

  String _t(String zh, String en, String ja) => switch (_language) {
    'zh' => zh,
    'ja' => ja,
    _ => en,
  };

  String get title => _t('智能任务建议', 'Smart task suggestions', 'スマートタスク提案');
  String entrySubtitle({required bool localEnabled, required bool aiEnabled}) {
    if (aiEnabled) {
      return _t(
        '本地预测与大模型增强已开启',
        'Local prediction and AI enhancement enabled',
        'ローカル予測と AI 補助が有効',
      );
    }
    if (localEnabled) {
      return _t(
        '本地截止时间预测已开启',
        'Local deadline prediction enabled',
        'ローカル期限予測が有効',
      );
    }
    return _t(
      '配置本地预测和大模型增强',
      'Configure local prediction and AI enhancement',
      'ローカル予測と AI 補助を設定',
    );
  }

  String get enabled =>
      _t('启用本地截止时间预测', 'Enable local deadline prediction', 'ローカル期限予測を有効化');
  String get enabledHint => _t(
    '根据历史任务行为自动填写新任务截止时间',
    'Use task history to fill new task deadlines',
    '履歴から新しいタスクの期限を自動入力',
  );
  String get aiEnabled => _t('启用大模型增强', 'Enable AI enhancement', 'AI 補助を有効化');
  String get aiHint => _t(
    '调用你配置的模型润色内容并推荐节点',
    'Use your configured model to polish content and suggest milestones',
    '設定したモデルで内容と中間期限を提案',
  );
  String get stepByStep =>
      _t('分步骤生成建议', 'Generate suggestions in steps', '段階的に提案を生成');
  String get stepByStepHint => _t(
    '先规划截止时间和节点，再润色任务内容',
    'Plan the deadline and milestones before polishing task content',
    '期限と中間ノードを計画してから内容を整える',
  );
  String get protocol => _t('协议', 'Protocol', 'プロトコル');
  String get baseUrl => _t('Base URL', 'Base URL', 'Base URL');
  String get model => _t('模型', 'Model', 'モデル');
  String get apiKey => _t('API Key', 'API Key', 'API Key');
  String get apiKeySaved =>
      _t('API Key 已安全保存', 'API key is securely saved', 'API Key は安全に保存されています');
  String get save => _t('保存智能设置', 'Save smart settings', 'スマート設定を保存');
  String get prompt => _t('自定义提示词', 'Custom prompt', 'カスタムプロンプト');
  String get promptHint => _t(
    '可选。留空使用内置提示词。',
    'Optional. Leave blank to use the built-in prompt.',
    '任意。空欄で内蔵プロンプトを使用',
  );
  String get privacy => _t(
    '启用大模型后，任务标题、备注和标签可能会发送到你配置的服务。',
    'When AI is enabled, task titles, notes and tags may be sent to your configured provider.',
    'AI を有効にすると、タイトル、メモ、タグが設定したサービスへ送信される場合があります。',
  );
}
