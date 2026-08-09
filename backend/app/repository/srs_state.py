"""Acesso e persistência do estado de SRS por par usuário-questão."""

import uuid
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.entities import UserQuestionState
from app.repository import mappers
from app.repository.orm_models import UserQuestionStateORM


def get_or_default(db: Session, user_id: uuid.UUID, question_id: uuid.UUID) -> UserQuestionState:
    """Estado de SRS do par usuário-questão, ou o default de uma questão nunca vista."""
    row = db.get(UserQuestionStateORM, (user_id, question_id))
    if row is None:
        return UserQuestionState(user_id=user_id, question_id=question_id)
    return mappers.user_question_state_to_entity(row)


def get_all_for_topic(
    db: Session, user_id: uuid.UUID, question_ids: list[uuid.UUID]
) -> dict[uuid.UUID, UserQuestionState]:
    """Estados de SRS já existentes para as questões de um tópico, por question_id.

    Questões sem entrada aqui ainda não foram vistas pelo usuário — quem
    monta a lição/calcula mastery trata a ausência como o default de
    `UserQuestionState` (RF-03, RF-06).
    """
    if not question_ids:
        return {}

    rows = db.scalars(
        select(UserQuestionStateORM).where(
            UserQuestionStateORM.user_id == user_id,
            UserQuestionStateORM.question_id.in_(question_ids),
        )
    ).all()
    return {row.question_id: mappers.user_question_state_to_entity(row) for row in rows}


def count_questions_seen(db: Session, user_id: uuid.UUID, question_ids: list[uuid.UUID]) -> int:
    """Quantas questões desse conjunto o usuário já respondeu ao menos uma vez.

    Uma linha em user_question_state só existe depois da primeira resposta
    (ver `save` abaixo) — contar linhas é contar questões já vistas, usado
    pelo gate de desbloqueio (RF-09).
    """
    if not question_ids:
        return 0

    count = db.scalar(
        select(func.count()).select_from(
            select(UserQuestionStateORM)
            .where(
                UserQuestionStateORM.user_id == user_id,
                UserQuestionStateORM.question_id.in_(question_ids),
            )
            .subquery()
        )
    )
    return count or 0


def save(db: Session, state: UserQuestionState, *, last_reviewed_at: datetime) -> UserQuestionState:
    """Grava (upsert) o novo estado de SRS após uma resposta.

    `due_date` é calculado aqui, não no motor (ver docstring de
    app/motor/srs.py): a camada de serviço/repositório soma `interval_days`
    à data da resposta. Erro (interval_days == 0) marca a questão como
    devida imediatamente.
    """
    row = db.get(UserQuestionStateORM, (state.user_id, state.question_id))
    if row is None:
        row = UserQuestionStateORM(user_id=state.user_id, question_id=state.question_id)
        db.add(row)

    row.repetition_count = state.repetition_count
    row.ease_factor = state.ease_factor
    row.interval_days = state.interval_days
    row.due_date = last_reviewed_at.date() + timedelta(days=state.interval_days)
    row.last_reviewed_at = last_reviewed_at

    db.commit()
    db.refresh(row)
    return mappers.user_question_state_to_entity(row)
