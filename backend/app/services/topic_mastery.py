"""Cálculo de mastery de um tópico para um usuário — usado tanto por
progress_service (RF-02) quanto por session_service (RF-09, RF-11), para
as duas rotas nunca calcularem mastery de formas diferentes."""

import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy.orm import Session

from app.models.entities import UserQuestionState
from app.motor.mastery import probability_of_recall, topic_mastery_pct
from app.repository import catalog, srs_state


@dataclass(frozen=True)
class TopicMasterySnapshot:
    question_ids: list[uuid.UUID]
    mastery_pct: float
    questions_seen: int


def _snapshot_from_states(
    question_ids: list[uuid.UUID],
    states: dict[uuid.UUID, UserQuestionState],
    today: date,
) -> TopicMasterySnapshot:
    probabilities = []
    for question_id in question_ids:
        state = states.get(question_id)
        if state is None or state.last_reviewed_at is None:
            probabilities.append(
                0.0
            )  # nunca respondida — motor.mastery trata como esquecida
            continue

        days_since_last_review = (today - state.last_reviewed_at.date()).days
        probabilities.append(
            probability_of_recall(
                interval_days=state.interval_days,
                days_since_last_review=days_since_last_review,
            )
        )

    return TopicMasterySnapshot(
        question_ids=question_ids,
        mastery_pct=topic_mastery_pct(probabilities),
        questions_seen=len(states),
    )


def compute(
    db: Session, user_id: uuid.UUID, topic_id: uuid.UUID, today: date
) -> TopicMasterySnapshot:
    question_ids = catalog.get_topic_question_ids(db, topic_id)
    states = srs_state.get_all_for_topic(db, user_id, question_ids)
    return _snapshot_from_states(question_ids, states, today)


def compute_many(
    db: Session, user_id: uuid.UUID, topic_ids: list[uuid.UUID], today: date
) -> dict[uuid.UUID, TopicMasterySnapshot]:
    """Igual a `compute`, só que pra vários tópicos de uma vez — usado por
    certifications_service e progress_service, que antes chamavam
    `compute` num loop por tópico (N+1: 2 queries × N tópicos). Aqui são só
    2 queries no total, não importa quantos tópicos.

    Resultado idêntico a chamar `compute` pra cada topic_id individualmente
    — só a forma de buscar os dados muda, não o cálculo de mastery."""
    if not topic_ids:
        return {}

    question_ids_by_topic = catalog.get_question_ids_by_topics(db, topic_ids)
    all_question_ids = [
        question_id
        for question_ids in question_ids_by_topic.values()
        for question_id in question_ids
    ]
    all_states = srs_state.get_all_for_topic(db, user_id, all_question_ids)

    return {
        topic_id: _snapshot_from_states(
            question_ids_by_topic.get(topic_id, []), all_states, today
        )
        for topic_id in topic_ids
    }
