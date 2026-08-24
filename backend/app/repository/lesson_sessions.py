"""Sessões de lição (alimentam o streak, RF-08) e gate de tópico (RF-09)."""

import uuid
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.entities import LessonSession, UserTopicProgress
from app.repository import mappers
from app.repository.orm_models import LessonSessionORM, UserTopicProgressORM


def create(
    db: Session, *, user_id: uuid.UUID, topic_id: uuid.UUID, started_at: datetime
) -> LessonSession:
    row = LessonSessionORM(user_id=user_id, topic_id=topic_id, started_at=started_at)
    db.add(row)
    db.commit()
    db.refresh(row)
    return mappers.lesson_session_to_entity(row)


def get(db: Session, session_id: uuid.UUID, user_id: uuid.UUID) -> LessonSession | None:
    """Busca sempre escopada ao dono da sessão — nunca só pelo `session_id`,
    senão qualquer usuário autenticado poderia ler/completar a sessão de
    outro (IDOR: ver revisão de segurança)."""
    row = db.scalar(
        select(LessonSessionORM).where(
            LessonSessionORM.id == session_id, LessonSessionORM.user_id == user_id
        )
    )
    return mappers.lesson_session_to_entity(row) if row else None


def complete(
    db: Session, session_id: uuid.UUID, user_id: uuid.UUID, *, completed_at: datetime, xp_earned: int
) -> LessonSession:
    row = db.scalar(
        select(LessonSessionORM).where(
            LessonSessionORM.id == session_id, LessonSessionORM.user_id == user_id
        )
    )
    if row is None:
        raise ValueError(f"lesson_session {session_id} não encontrada")

    row.completed_at = completed_at
    row.xp_earned = xp_earned
    db.commit()
    db.refresh(row)
    return mappers.lesson_session_to_entity(row)


def get_topic_progress(db: Session, user_id: uuid.UUID, topic_id: uuid.UUID) -> UserTopicProgress:
    row = db.get(UserTopicProgressORM, (user_id, topic_id))
    if row is None:
        return UserTopicProgress(user_id=user_id, topic_id=topic_id)
    return mappers.user_topic_progress_to_entity(row)


def unlock_topic(
    db: Session, user_id: uuid.UUID, topic_id: uuid.UUID, *, unlocked_at: datetime
) -> UserTopicProgress:
    row = db.get(UserTopicProgressORM, (user_id, topic_id))
    if row is None:
        row = UserTopicProgressORM(user_id=user_id, topic_id=topic_id)
        db.add(row)

    row.unlocked = True
    row.unlocked_at = unlocked_at
    db.commit()
    db.refresh(row)
    return mappers.user_topic_progress_to_entity(row)
