"""`POST /question/{id}/answer` — registra resposta (RF-04, RF-05, RF-07, RF-10)."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.models.entities import AppUser
from app.repository import catalog
from app.repository.db import get_db
from app.routers.deps import get_current_app_user
from app.routers.schemas import AnswerRequest, AnswerResponse, ChoiceExplanationResponse
from app.services import answer_service

router = APIRouter(tags=["answer"])


@router.post("/question/{question_id}/answer", response_model=AnswerResponse)
def answer_question(
    question_id: uuid.UUID,
    body: AnswerRequest,
    user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
) -> AnswerResponse:
    try:
        result = answer_service.answer_question(
            db,
            user_id=user.id,
            question_id=question_id,
            choice_id=body.choice_id,
            now=datetime.now(timezone.utc),
        )
    except ValueError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc

    # RF-04: explicação de TODAS as alternativas, não só a escolhida.
    questions_with_choices = catalog.get_questions_with_choices(db, [question_id])
    choices = questions_with_choices[0][1] if questions_with_choices else []

    return AnswerResponse(
        is_correct=result.is_correct,
        xp_earned=result.xp_earned,
        choices=[
            ChoiceExplanationResponse(
                id=choice.id,
                text=choice.text,
                is_correct=choice.is_correct,
                explanation=choice.explanation,
            )
            for choice in choices
        ],
    )
