/// Espelha LessonResponse/LessonQuestionResponse/LessonChoiceResponse em
/// backend/app/routers/schemas.py — POST /topic/{id}/lesson (RF-03).
///
/// `LessonChoice` deliberadamente NÃO tem is_correct/explanation — o
/// backend não manda isso antes do usuário responder (RF-04); ver
/// AnswerChoice em answer.dart pra depois de responder.
class LessonChoice {
  final String id;
  final String text;

  const LessonChoice({required this.id, required this.text});

  factory LessonChoice.fromJson(Map<String, dynamic> json) {
    return LessonChoice(id: json['id'] as String, text: json['text'] as String);
  }
}

class LessonQuestion {
  final String id;
  final String prompt;
  final List<LessonChoice> choices;

  const LessonQuestion({required this.id, required this.prompt, required this.choices});

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    return LessonQuestion(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      choices: (json['choices'] as List)
          .map((c) => LessonChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Lesson {
  final String sessionId;
  final List<LessonQuestion> questions;

  const Lesson({required this.sessionId, required this.questions});

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      sessionId: json['session_id'] as String,
      questions: (json['questions'] as List)
          .map((q) => LessonQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}
