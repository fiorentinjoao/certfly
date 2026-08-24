import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../models/answer.dart';
import '../models/lesson.dart';
import '../theme.dart';
import '../widgets/animated_progress_bar.dart';
import '../widgets/app_page_route.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/skeleton.dart';
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
      // Feedback tátil no momento da resposta — reforça acerto/erro sem
      // depender só de cor/ícone na tela (padrão comum em apps de hábito).
      if (result.isCorrect) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _retryLesson() {
    setState(() => _lessonFuture = widget.apiClient.startLesson(widget.topicId));
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
    await Navigator.of(context).push(appPageRoute(LessonSummaryScreen(summary: summary)));
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
              return const _QuestionSkeleton();
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Não consegui gerar a lição',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _retryLesson, child: const Text('Tentar novamente')),
                    ],
                  ),
                ),
              );
            }

            final lesson = snapshot.data!;
            if (lesson.questions.isEmpty) {
              return const Center(child: Text('Nenhuma questão disponível pra esse tópico ainda.'));
            }

            final question = lesson.questions[_currentIndex];
            final isLast = _currentIndex == lesson.questions.length - 1;

            return Column(
              children: [
                AnimatedProgressBar(
                  value: (_currentIndex + (_currentAnswer != null ? 1 : 0)) / lesson.questions.length,
                  minHeight: 4,
                  backgroundColor: AppColors.line,
                  valueColor: AppColors.purple,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: ListView(
                      // key por questão: força o AnimatedSwitcher a tratar
                      // cada questão como um widget novo, disparando o
                      // crossfade ao avançar em vez de atualizar in-place.
                      key: ValueKey(question.id),
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
                          FadeSlideIn(
                            child: _XpBadge(
                              xpEarned: _currentAnswer!.xpEarned,
                              isCorrect: _currentAnswer!.isCorrect,
                            ),
                          ),
                        ],
                      ],
                    ),
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

/// Esboço da pergunta + alternativas enquanto a lição é gerada
/// (POST /topic/{id}/lesson pode levar um instante — motor de SRS decide
/// quais questões entram) — no lugar de um spinner sem forma.
class _QuestionSkeleton extends StatelessWidget {
  const _QuestionSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Skeleton(width: 140, height: 12, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 12),
        const Skeleton(width: double.infinity, height: 22, borderRadius: BorderRadius.all(Radius.circular(6))),
        const SizedBox(height: 8),
        Skeleton(width: 220, height: 22, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 24),
        for (var i = 0; i < 4; i++) ...[
          Skeleton(width: double.infinity, height: 56, borderRadius: BorderRadius.circular(14)),
          const SizedBox(height: 12),
        ],
      ],
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

    Color borderColor = Colors.transparent;
    Color tintColor = AppColors.surface;
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tintColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: trailingIcon != null
                          ? Icon(trailingIcon, color: borderColor, key: ValueKey(trailingIcon))
                          : const SizedBox.shrink(key: ValueKey('none')),
                    ),
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
