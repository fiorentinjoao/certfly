"""Registra a resposta de uma questão (RF-04, RF-05, RF-07, RF-10) —
`POST /question/{id}/answer`. É aqui que o motor puro (srs, xp) encontra o
mundo com estado: lê o estado atual, chama o motor, grava o resultado."""

import uuid
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy.orm import Session

from app.models.entities import Choice, UserQuestionState
from app.motor.srs import SRSState, apply_answer
from app.motor.xp import xp_for_answer
from app.repository import attempts, catalog, srs_state, users


@dataclass(frozen=True)
class AnswerResult:
    choice: Choice
    is_correct: bool
    xp_earned: int


def answer_question(
    db: Session,
    *,
    user_id: uuid.UUID,
    question_id: uuid.UUID,
    choice_id: uuid.UUID,
    now: datetime,
) -> AnswerResult:
    choice = catalog.get_choice(db, choice_id)
    if choice is None or choice.question_id != question_id:
        raise ValueError("choice não pertence à questão informada")

    current_state = srs_state.get_or_default(db, user_id, question_id)
    # "Nova" = nunca respondida antes, certa ou errada — distingue de
    # "revisão" pro XP motor (RF-07), independente do que o motor de SRS
    # calcula pra esta resposta.
    is_new_question = current_state.last_reviewed_at is None

    motor_state = SRSState(
        repetition_count=current_state.repetition_count,
        ease_factor=current_state.ease_factor,
        interval_days=current_state.interval_days,
    )
    new_motor_state = apply_answer(motor_state, correct=choice.is_correct)

    xp_earned = xp_for_answer(is_new_question=is_new_question, is_correct=choice.is_correct)

    updated_state = UserQuestionState(
        user_id=user_id,
        question_id=question_id,
        repetition_count=new_motor_state.repetition_count,
        ease_factor=new_motor_state.ease_factor,
        interval_days=new_motor_state.interval_days,
    )
    srs_state.save(db, updated_state, last_reviewed_at=now)

    attempts.record(
        db,
        user_id=user_id,
        question_id=question_id,
        choice_id=choice_id,
        is_correct=choice.is_correct,
        xp_earned=xp_earned,
        answered_at=now,
    )

    if xp_earned > 0:
        users.add_xp(db, user_id, xp_earned)

    return AnswerResult(choice=choice, is_correct=choice.is_correct, xp_earned=xp_earned)
