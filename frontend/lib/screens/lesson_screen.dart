import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/answer.dart';
import '../models/lesson.dart';
import '../theme.dart';
import 'lesson_summary_screen.dart';

/// POST /topic/{id}/lesson (RF-03) + POST /question/{id}/answer (RF-04,
/// RF-05, RF-07) — uma questão por vez, com explicação de todas as
/// alternativas depois de responder.
class LessonScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String topicId;
  final String topicName;

  const LessonScreen({
    super.key,
    required this.apiClient,
    required this.topicId,
    required this.topicName,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late Future<Lesson> _lessonFuture;

  int _currentIndex = 0;
  AnswerResult? _currentAnswer;
  String? _selectedChoiceId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _lessonFuture = widget.apiClient.startLesson(widget.topicId);
  }

  Future<void> _submitAnswer(String sessionId, LessonQuestion question, String choiceId) async {
    setState(() {
      _submitting = true;
      _selectedChoiceId = choiceId;
    });
    try {
      final result = await widget.apiClient.answerQuestion(question.id, choiceId);
      setState(() => _currentAnswer = result);
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _next(Lesson lesson) async {
    if (_currentIndex < lesson.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _currentAnswer = null;
        _selectedChoiceId = null;
      });
      return;
    }

    // Última questão — fecha a sessão e mostra o resumo (RF-08, RF-09, RF-11).
    setState(() => _submitting = true);
    final summary = await widget.apiClient.completeLessonSession(lesson.sessionId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LessonSummaryScreen(summary: summary)),
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.topicName)),
      body: SafeArea(
        child: FutureBuilder<Lesson>(
          future: _lessonFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erro ao gerar a lição: ${snapshot.error}'));
            }

            final lesson = snapshot.data!;
            if (lesson.questions.isEmpty) {
              return const Center(child: Text('Nenhuma questão disponível pra esse tópico ainda.'));
            }

            final question = lesson.questions[_currentIndex];
            final isLast = _currentIndex == lesson.questions.length - 1;

            return Column(
              children: [
                LinearProgressIndicator(
                  value: (_currentIndex + (_currentAnswer != null ? 1 : 0)) / lesson.questions.length,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'QUESTÃO ${_currentIndex + 1} DE ${lesson.questions.length}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(letterSpacing: 0.6, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(question.prompt, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 20),
                      for (final choice in question.choices)
                        _ChoiceCard(
                          choice: choice,
                          selected: choice.id == _selectedChoiceId,
                          answer: _currentAnswer,
                          enabled: _currentAnswer == null && !_submitting,
                          onTap: () => _submitAnswer(lesson.sessionId, question, choice.id),
                        ),
                      if (_currentAnswer != null) ...[
                        const SizedBox(height: 8),
                        _XpBadge(xpEarned: _currentAnswer!.xpEarned, isCorrect: _currentAnswer!.isCorrect),
                      ],
                    ],
                  ),
                ),
                if (_currentAnswer != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : () => _next(lesson),
                        child: Text(isLast ? 'Finalizar lição' : 'Continuar'),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final LessonChoice choice;
  final bool selected;
  final AnswerResult? answer;
  final bool enabled;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.choice,
    required this.selected,
    required this.answer,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AnswerChoice? explained;
    if (answer != null) {
      for (final c in answer!.choices) {
        if (c.id == choice.id) explained = c;
      }
    }

    Color? borderColor;
    Color? tintColor;
    IconData? trailingIcon;
    if (explained != null) {
      if (explained.isCorrect) {
        borderColor = AppColors.green;
        tintColor = AppColors.green.withValues(alpha: 0.12);
        trailingIcon = Icons.check_circle_rounded;
      } else if (selected) {
        borderColor = AppColors.red;
        tintColor = AppColors.red.withValues(alpha: 0.12);
        trailingIcon = Icons.cancel_rounded;
      }
    }

    return Card(
      color: tintColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: borderColor != null ? BorderSide(color: borderColor, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(choice.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (trailingIcon != null) Icon(trailingIcon, color: borderColor),
                ],
              ),
              if (explained != null) ...[
                const SizedBox(height: 8),
                Text(explained.explanation, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _XpBadge extends StatelessWidget {
  final int xpEarned;
  final bool isCorrect;
  const _XpBadge({required this.xpEarned, required this.isCorrect});

  @override
  Widget build(BuildContext context) {
    final label = isCorrect ? '+$xpEarned XP' : 'Sem XP dessa vez';
    final color = isCorrect ? AppColors.green : AppColors.red;
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(isCorrect ? Icons.bolt_rounded : Icons.close_rounded, color: Colors.white, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: color,
      ),
    );
  }
}
