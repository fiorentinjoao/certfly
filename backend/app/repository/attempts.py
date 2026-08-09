"""Log imutável de tentativas de resposta (RF-10) — histórico/analytics,
separado do estado mutável de SRS (repository/srs_state.py)."""

import uuid
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.entities import Attempt
from app.repository import mappers
from app.repository.orm_models import AttemptORM


def record(
    db: Session,
    *,
    user_id: uuid.UUID,
    question_id: uuid.UUID,
    choice_id: uuid.UUID,
    is_correct: bool,
    xp_earned: int,
    answered_at: datetime,
) -> Attempt:
    row = AttemptORM(
        user_id=user_id,
        question_id=question_id,
        choice_id=choice_id,
        is_correct=is_correct,
        xp_earned=xp_earned,
        answered_at=answered_at,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return mappers.attempt_to_entity(row)


def sum_xp_since(
    db: Session, user_id: uuid.UUID, question_ids: list[uuid.UUID], since: datetime
) -> int:
    """Soma o XP de todas as tentativas de um usuário, dentro de um conjunto de
    questões, desde um instante (`lesson_session.started_at`). Usado para
    fechar o resumo de uma sessão de lição (RF-11) sem precisar de uma FK
    attempt -> lesson_session, que não existe no schema (docs/system-design.md)."""
    if not question_ids:
        return 0

    total = db.scalar(
        select(func.coalesce(func.sum(AttemptORM.xp_earned), 0)).where(
            AttemptORM.user_id == user_id,
            AttemptORM.question_id.in_(question_ids),
            AttemptORM.answered_at >= since,
        )
    )
    return total or 0
