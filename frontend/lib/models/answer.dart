/// Espelha AnswerResponse/ChoiceExplanationResponse em
/// backend/app/routers/schemas.py — POST /question/{id}/answer (RF-04, RF-05, RF-07).
class AnswerChoice {
  final String id;
  final String text;
  final bool isCorrect;
  final String explanation;

  const AnswerChoice({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.explanation,
  });

  factory AnswerChoice.fromJson(Map<String, dynamic> json) {
    return AnswerChoice(
      id: json['id'] as String,
      text: json['text'] as String,
      isCorrect: json['is_correct'] as bool,
      explanation: json['explanation'] as String,
    );
  }
}

class AnswerResult {
  final bool isCorrect;
  final int xpEarned;
  final List<AnswerChoice> choices;

  const AnswerResult({required this.isCorrect, required this.xpEarned, required this.choices});

  factory AnswerResult.fromJson(Map<String, dynamic> json) {
    return AnswerResult(
      isCorrect: json['is_correct'] as bool,
      xpEarned: json['xp_earned'] as int,
      choices: (json['choices'] as List)
          .map((c) => AnswerChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
