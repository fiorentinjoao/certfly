"""Motor de mastery — % de domínio por tópico e gate de desbloqueio.

Lógica de negócio pura: sem I/O, sem banco, sem relógio. Assim como em
app/motor/srs.py, o "tempo" nunca é lido daqui de dentro (nada de
`datetime.now()`) — `days_since_last_review` é calculado pela camada de
serviço a partir de `due_date`/`last_reviewed_at` e passado como argumento,
para manter este módulo determinístico e testável sem mockar relógio.

Regras completas: docs/core-loop-srs.md
"""

from collections.abc import Sequence

MASTERY_UNLOCK_THRESHOLD = 0.8
"""% de domínio mínimo do tópico para desbloquear o próximo (RF-09)."""


def probability_of_recall(*, interval_days: int, days_since_last_review: int) -> float:
    """Estima a probabilidade de o usuário lembrar uma questão agora.

    Aproximação simplificada do half-life regression do Duolingo (ver
    docs/market-research.md): usa o próprio `interval_days` da questão
    (calculado pelo motor de SRS) como proxy do "half-life" da curva de
    esquecimento.

        p = 0.5 ^ (dias_desde_ultima_revisao / interval_days)

    Uma questão nunca respondida com sucesso (ou que acabou de ser errada)
    tem `interval_days == 0` — não tem half-life definido, então conta como
    esquecida (p = 0.0) em vez de propagar um ZeroDivisionError.
    """
    if interval_days <= 0:
        return 0.0

    return 0.5 ** (days_since_last_review / interval_days)


def topic_mastery_pct(question_probabilities: Sequence[float]) -> float:
    """% de domínio de um tópico = média de `probability_of_recall` das suas questões.

    Questões nunca introduzidas ao usuário devem entrar nesta sequência já
    como `0.0` (é responsabilidade de quem monta a sequência, não deste
    motor, decidir quais questões pertencem ao tópico — ver docs/core-loop-srs.md).
    Um tópico sem nenhuma questão cadastrada não tem domínio possível: 0.0.
    """
    if not question_probabilities:
        return 0.0

    return sum(question_probabilities) / len(question_probabilities)


def is_topic_unlocked(
    *, mastery_pct: float, questions_seen: int, min_questions_seen: int
) -> bool:
    """Verifica o gate de desbloqueio do próximo tópico (RF-09).

    Duas condições, ambas necessárias:
    - `mastery_pct >= MASTERY_UNLOCK_THRESHOLD` (80%)
    - `questions_seen >= min_questions_seen` — evita destravar com amostra
      pequena (ex: acertar as 2 únicas questões já vistas de um pool de 15
      não deveria contar como "domínio"). `min_questions_seen` é decisão de
      conteúdo (tamanho do pool daquele tópico), não deste motor.
    """
    return mastery_pct >= MASTERY_UNLOCK_THRESHOLD and questions_seen >= min_questions_seen
