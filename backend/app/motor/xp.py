"""Motor de XP e streak — docs/core-loop-srs.md, seção 4.

Lógica de negócio pura: sem I/O, sem banco, sem relógio (a exemplo de
app/motor/srs.py e app/motor/mastery.py). `today` é sempre recebido como
argumento, nunca lido de `datetime.now()` aqui dentro — mantém o motor
determinístico e testável sem mockar relógio.
"""

from datetime import date, timedelta

XP_NEW_QUESTION_CORRECT = 10
"""XP por acertar uma questão respondida certa pela primeira vez."""

XP_REVIEW_CORRECT = 3
"""XP por acertar uma questão em revisão (menor que XP_NEW_QUESTION_CORRECT
de propósito — recompensa mais quem avança em conteúdo novo, mas ainda
incentiva revisão o bastante pra não ser ignorada)."""


def xp_for_answer(*, is_new_question: bool, is_correct: bool) -> int:
    """XP ganho ao responder uma questão (RF-07).

    Só questões respondidas CERTO concedem XP — "respondida certa pela
    primeira vez" / "revisão bem-sucedida" em core-loop-srs.md. Errar não
    concede nem desconta XP.
    """
    if not is_correct:
        return 0

    return XP_NEW_QUESTION_CORRECT if is_new_question else XP_REVIEW_CORRECT


def update_streak(*, current_streak: int, last_active_date: date | None, today: date) -> int:
    """Novo valor do streak ao completar uma lição hoje (RF-08).

    Session-based: não importa quantas lições no dia, só se pelo menos uma
    foi completada.

    - Já tinha completado uma lição hoje → streak não muda (idempotente,
      completar 2 lições no mesmo dia não infla o streak)
    - Última lição foi ontem → streak continua, +1
    - Qualquer outro caso (nunca estudou, ou quebrou a sequência) → reinicia em 1
    """
    if last_active_date == today:
        return current_streak

    if last_active_date == today - timedelta(days=1):
        return current_streak + 1

    return 1
