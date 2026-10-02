import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_prediction_settings.dart';
import 'ai_secret_store.dart';

class AiTaskInput {
  const AiTaskInput({
    required this.title,
    required this.note,
    required this.tags,
    required this.nowUtc,
    required this.localPredictionHours,
  });

  final String title;
  final String note;
  final List<String> tags;
  final DateTime nowUtc;
  final double localPredictionHours;
}

class AiTaskSuggestion {
  const AiTaskSuggestion({
    this.title,
    this.note,
    this.tags = const [],
    this.deadlineOffsetHours,
    this.milestones = const [],
  });

  final String? title;
  final String? note;
  final List<String> tags;
  final double? deadlineOffsetHours;
  final List<AiMilestoneSuggestion> milestones;

  factory AiTaskSuggestion.fromJson(Map<String, dynamic> json) {
    final rawMilestones = json['milestones'];
    return AiTaskSuggestion(
      title: (json['title'] as String?)?.trim(),
      note: (json['note'] as String?)?.trim(),
      tags: (json['tags'] as List? ?? const [])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(),
      deadlineOffsetHours: (json['deadlineOffsetHours'] as num?)?.toDouble(),
      milestones: (rawMilestones is List ? rawMilestones : const [])
          .whereType<Map>()
          .map(
            (item) => AiMilestoneSuggestion(
              title: (item['title'] as String? ?? '').trim(),
              offsetHours: (item['offsetHours'] as num?)?.toDouble() ?? 0,
            ),
          )
          .where((item) => item.offsetHours > 0)
          .toList(),
    );
  }
}

class AiMilestoneSuggestion {
  const AiMilestoneSuggestion({required this.title, required this.offsetHours});
  final String title;
  final double offsetHours;
}

class AiTaskService {
  AiTaskService({http.Client? client, AiSecretStore? secrets})
    : _client = client ?? http.Client(),
      _secrets = secrets ?? AiSecretStore();

  final http.Client _client;
  final AiSecretStore _secrets;

  Future<AiTaskSuggestion> suggest(
    AppPredictionSettings settings,
    AiTaskInput input,
  ) async {
    final apiKey = await _secrets.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiTaskException('Missing API key');
    }
    if (settings.baseUrl.trim().isEmpty || settings.model.trim().isEmpty) {
      throw const AiTaskException('AI provider is not configured');
    }
    final prompt = _prompt(settings, input);
    if (settings.stepByStep) {
      final plan = await _send(settings, apiKey, _planningPrompt(input));
      final refinementPrompt =
          '$prompt\n'
          'Planning result to preserve:\n'
          '${jsonEncode({
            'deadlineOffsetHours': plan.deadlineOffsetHours,
            'milestones': [
              for (final milestone in plan.milestones) {'title': milestone.title, 'offsetHours': milestone.offsetHours},
            ],
          })}\n'
          'Now polish the title, note and tags while preserving valid planning values.';
      final refined = await _send(settings, apiKey, refinementPrompt);
      return AiTaskSuggestion(
        title: refined.title ?? input.title,
        note: refined.note ?? input.note,
        tags: refined.tags.isEmpty ? plan.tags : refined.tags,
        deadlineOffsetHours:
            refined.deadlineOffsetHours ?? plan.deadlineOffsetHours,
        milestones: refined.milestones.isEmpty
            ? plan.milestones
            : refined.milestones,
      );
    }
    return _send(settings, apiKey, prompt);
  }

  Future<AiTaskSuggestion> _send(
    AppPredictionSettings settings,
    String apiKey,
    String prompt,
  ) async {
    final request = _request(settings, apiKey, prompt);
    final response = await _client
        .post(
          request.uri,
          headers: request.headers,
          body: jsonEncode(request.body),
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiTaskException('AI request failed (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final text = _responseText(settings.aiProtocol, decoded);
    try {
      final json = jsonDecode(_stripCodeFence(text));
      if (json is! Map) throw const FormatException('Expected object');
      return AiTaskSuggestion.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      throw const AiTaskException('AI returned invalid structured data');
    }
  }

  ({Uri uri, Map<String, String> headers, Map<String, dynamic> body}) _request(
    AppPredictionSettings settings,
    String apiKey,
    String prompt,
  ) {
    final base = settings.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final headers = <String, String>{'Content-Type': 'application/json'};
    late String path;
    late Map<String, dynamic> body;
    switch (settings.aiProtocol) {
      case AiProtocol.chatCompletions:
        path = _endpointPath(base, '/v1/chat/completions');
        headers['Authorization'] = 'Bearer $apiKey';
        body = {
          'model': settings.model,
          'temperature': 0.2,
          'messages': [
            {'role': 'system', 'content': _systemPrompt(settings.customPrompt)},
            {'role': 'user', 'content': prompt},
          ],
        };
      case AiProtocol.responses:
        path = _endpointPath(base, '/v1/responses');
        headers['Authorization'] = 'Bearer $apiKey';
        body = {
          'model': settings.model,
          'input': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'input_text',
                  'text': '${_systemPrompt(settings.customPrompt)}\n$prompt',
                },
              ],
            },
          ],
        };
      case AiProtocol.anthropicMessages:
        path = _endpointPath(base, '/v1/messages');
        headers['x-api-key'] = apiKey;
        headers['anthropic-version'] = '2023-06-01';
        body = {
          'model': settings.model,
          'max_tokens': 1200,
          'system': _systemPrompt(settings.customPrompt),
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        };
    }
    return (uri: Uri.parse('$base$path'), headers: headers, body: body);
  }

  String _endpointPath(String base, String endpoint) {
    if (base.endsWith(endpoint)) return '';
    if (base.endsWith('/v1')) return endpoint.substring(3);
    return endpoint;
  }

  String _systemPrompt(String custom) =>
      '''Return only valid JSON with this shape:
{"title":"string","note":"string","tags":["string"],"deadlineOffsetHours":number,"milestones":[{"title":"string","offsetHours":number}]}
Preserve the user's meaning. deadlineOffsetHours must be between 1 and 2160. Every milestone offsetHours must be positive and less than deadlineOffsetHours. ${custom.trim()}''';

  String _prompt(AppPredictionSettings settings, AiTaskInput input) =>
      'Current UTC: ${input.nowUtc.toIso8601String()}\n'
      'Local statistical prediction: ${input.localPredictionHours.toStringAsFixed(1)} hours\n'
      'Title: ${input.title}\nNote: ${input.note}\nTags: ${input.tags.join(', ')}';

  String _planningPrompt(AiTaskInput input) =>
      'Current UTC: ${input.nowUtc.toIso8601String()}\n'
      'Local statistical prediction: ${input.localPredictionHours.toStringAsFixed(1)} hours\n'
      'Title: ${input.title}\nNote: ${input.note}\nTags: ${input.tags.join(', ')}\n'
      'Return a conservative deadlineOffsetHours and useful milestones. '
      'Title, note and tags may be returned unchanged.';

  String _responseText(AiProtocol protocol, dynamic decoded) {
    if (protocol == AiProtocol.chatCompletions) {
      return decoded['choices'][0]['message']['content'] as String? ?? '';
    }
    if (protocol == AiProtocol.anthropicMessages) {
      return decoded['content'][0]['text'] as String? ?? '';
    }
    if (decoded['output_text'] is String) {
      return decoded['output_text'] as String;
    }
    for (final item in (decoded['output'] as List? ?? const [])) {
      for (final content in (item['content'] as List? ?? const [])) {
        if (content['text'] is String) return content['text'] as String;
      }
    }
    return '';
  }

  String _stripCodeFence(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '')
      .trim();
}

class AiTaskException implements Exception {
  const AiTaskException(this.message);
  final String message;
  @override
  String toString() => message;
}
