enum QuestionType {
  core('core', 'Core Summary', 'Key takeaways and architectural facts'),
  simpler('simpler', 'Explain Simpler', 'ELI5 breakdown demystifying jargon'),
  significance('significance', 'Why It Matters', 'Developer impact and industry shifts'),
  risk('risk', 'Risks & Trade-offs', 'Security flaws, lock-in, and ethical downsides');

  final String value;
  final String label;
  final String subtitle;

  const QuestionType(this.value, this.label, this.subtitle);

  static QuestionType fromValue(String val) {
    for (final type in QuestionType.values) {
      if (type.value == val) return type;
    }
    return QuestionType.core;
  }
}

class SummaryResponse {
  final String articleId;
  final QuestionType questionType;
  final List<String> content;
  final bool cached;
  final String modelUsed;
  final String promptVersion;
  final DateTime generatedAt;

  const SummaryResponse({
    required this.articleId,
    required this.questionType,
    required this.content,
    required this.cached,
    required this.modelUsed,
    required this.promptVersion,
    required this.generatedAt,
  });

  factory SummaryResponse.fromJson(Map<String, dynamic> json) {
    return SummaryResponse(
      articleId: json['article_id'] as String,
      questionType: QuestionType.fromValue(json['question_type'] as String? ?? 'core'),
      content: (json['content'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      cached: json['cached'] as bool? ?? false,
      modelUsed: json['model_used'] as String? ?? 'Pulse Wire Intelligence',
      promptVersion: json['prompt_version'] as String? ?? 'v1.0',
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'article_id': articleId,
      'question_type': questionType.value,
      'content': content,
      'cached': cached,
      'model_used': modelUsed,
      'prompt_version': promptVersion,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}
