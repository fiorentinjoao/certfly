"""Gera uma lição de um tópico (RF-03) — `POST /topic/{id}/lesson`."""

import uuid
from dataclasses import dataclass
from datetime import date, datetime

from sqlalchemy.orm import Session

from app.models import entities
from app.repository import catalog, lesson_sessions, srs_state

LESSON_SIZE = 10
"""Tamanho máximo de uma lição (RF-03: "8-10 questões")."""


@dataclass(frozen=True)
class LessonQuestion:
    question: entities.Question
    choices: list[entities.Choice]


@dataclass(frozen=True)
class Lesson:
    session: entities.LessonSession
    questions: list[LessonQuestion]


def start_lesson(
    db: Session, user_id: uuid.UUID, topic_id: uuid.UUID, today: date, now: datetime
) -> Lesson:
    """Monta até LESSON_SIZE questões de um tópico: revisão vencida primeiro
    (devolve o due_date <= hoje), completando com questões novas — e abre a
    lesson_session que rastreia essa lição (RF-03, RF-08)."""
    progress = lesson_sessions.get_topic_progress(db, user_id, topic_id)
    if not (progress.unlocked or catalog.is_entry_point_topic(db, topic_id)):
        # Gate de desbloqueio (RF-09) era só decorativo na UI — sem isso,
        # qualquer usuário autenticado podia chamar a API direto e pular
        # pra um tópico ainda bloqueado (ver revisão de segurança).
        raise PermissionError(
            f"tópico {topic_id} está bloqueado para o usuário {user_id}"
        )

    question_ids = catalog.get_topic_question_ids(db, topic_id)
    states = srs_state.get_all_for_topic(db, user_id, question_ids)

    due_ids = [
        question_id
        for question_id in question_ids
        if (state := states.get(question_id)) is not None
        and state.due_date is not None
        and state.due_date <= today
    ]
    new_ids = [question_id for question_id in question_ids if question_id not in states]

    selected_ids = (due_ids + new_ids)[:LESSON_SIZE]
    questions_with_choices = catalog.get_questions_with_choices(db, selected_ids)

    session = lesson_sessions.create(
        db, user_id=user_id, topic_id=topic_id, started_at=now
    )

    return Lesson(
        session=session,
        questions=[
            LessonQuestion(question=question, choices=choices)
            for question, choices in questions_with_choices
        ],
    )
