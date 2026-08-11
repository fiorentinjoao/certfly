"""Fecha uma sessão de lição (RF-08, RF-09, RF-11) —
`POST /lesson-session/{id}/complete`. Aqui o streak é atualizado e o gate
de desbloqueio do tópico é reavaliado."""

import math
import uuid
from dataclasses import dataclass
from datetime import date, datetime

from sqlalchemy.orm import Session

from app.motor.mastery import is_topic_unlocked
from app.motor.xp import update_streak
from app.repository import attempts, catalog, lesson_sessions, users
from app.services import topic_mastery

MIN_QUESTIONS_SEEN_RATIO = 8 / 15
"""Proporção mínima do pool de questões de um tópico que o usuário precisa
ter respondido para o gate poder avaliar desbloqueio — interpretação do
exemplo em docs/core-loop-srs.md ("8 de um pool de 15") como uma razão
aplicável a pools de tamanho diferente, não uma constante fixa. Reavaliar
se o tamanho real dos pools de conteúdo divergir muito de ~15 questões por
tópico."""


@dataclass(frozen=True)
class LessonSummary:
    """RF-11: resumo ao fim da lição — XP ganho, streak, mudança no domínio."""

    xp_earned: int
    current_streak: int
    mastery_pct: float
    topic_unlocked: bool


def complete_lesson_session(
    db: Session,
    *,
    session_id: uuid.UUID,
    user_id: uuid.UUID,
    today: date,
    now: datetime,
) -> LessonSummary:
    session = lesson_sessions.get(db, session_id)
    if session is None:
        raise ValueError(f"lesson_session {session_id} não encontrada")

    question_ids = catalog.get_topic_question_ids(db, session.topic_id)

    # attempt não tem FK pra lesson_session no schema (docs/system-design.md)
    # — o XP da sessão é a soma das tentativas desse usuário, nas questões
    # do tópico, desde que a sessão começou.
    xp_earned = attempts.sum_xp_since(
        db, user_id, question_ids, since=session.started_at
    )
    lesson_sessions.complete(db, session_id, completed_at=now, xp_earned=xp_earned)

    user = users.get_user(db, user_id)
    if user is None:
        raise ValueError(f"app_user {user_id} não encontrado")

    new_streak = update_streak(
        current_streak=user.current_streak,
        last_active_date=user.last_active_date,
        today=today,
    )
    users.update_streak(db, user_id, new_streak=new_streak, today=today)

    snapshot = topic_mastery.compute(db, user_id, session.topic_id, today)
    min_questions_seen = math.ceil(len(question_ids) * MIN_QUESTIONS_SEEN_RATIO)
    unlocked = is_topic_unlocked(
        mastery_pct=snapshot.mastery_pct,
        questions_seen=snapshot.questions_seen,
        min_questions_seen=min_questions_seen,
    )
    if unlocked:
        # Destrava o PRÓXIMO tópico da trilha, não o atual — o atual já é
        # acessível (é o próprio que o usuário acabou de fazer a lição
        # nele); marcar `session.topic_id` aqui era o bug: destravava o
        # tópico que já estava destravado e nunca liberava o seguinte.
        next_topic_id = catalog.get_next_topic_id(db, session.topic_id)
        if next_topic_id is not None:
            lesson_sessions.unlock_topic(db, user_id, next_topic_id, unlocked_at=now)

    return LessonSummary(
        xp_earned=xp_earned,
        current_streak=new_streak,
        mastery_pct=snapshot.mastery_pct,
        topic_unlocked=unlocked,
    )
