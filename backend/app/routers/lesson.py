"""`POST /topic/{id}/lesson` — gera uma lição (RF-03)."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.models.entities import AppUser
from app.repository.db import get_db
from app.routers.deps import get_current_app_user
from app.routers.schemas import (
    LessonChoiceResponse,
    LessonQuestionResponse,
    LessonResponse,
)
from app.services import lesson_service

router = APIRouter(tags=["lesson"])


@router.post("/topic/{topic_id}/lesson", response_model=LessonResponse)
def start_lesson(
    topic_id: uuid.UUID,
    user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
) -> LessonResponse:
    now = datetime.now(timezone.utc)
    try:
        lesson = lesson_service.start_lesson(
            db, user.id, topic_id, today=now.date(), now=now
        )
    except PermissionError as exc:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(exc)) from exc

    return LessonResponse(
        session_id=lesson.session.id,
        questions=[
            LessonQuestionResponse(
                id=lesson_question.question.id,
                prompt=lesson_question.question.prompt,
                # SEM is_correct/explanation aqui — vazaria a resposta
                # certa antes do usuário responder (RF-04). Só voltam em
                # POST /question/{id}/answer.
                choices=[
                    LessonChoiceResponse(id=choice.id, text=choice.text)
                    for choice in lesson_question.choices
                ],
            )
            for lesson_question in lesson.questions
        ],
    )
