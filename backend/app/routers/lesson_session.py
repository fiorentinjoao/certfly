"""`POST /lesson-session/{id}/complete` — fecha a lição (RF-08, RF-09, RF-11)."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.models.entities import AppUser
from app.repository.db import get_db
from app.routers.deps import get_current_app_user
from app.routers.schemas import LessonSummaryResponse
from app.services import session_service

router = APIRouter(tags=["lesson-session"])


@router.post("/lesson-session/{session_id}/complete", response_model=LessonSummaryResponse)
def complete_lesson_session(
    session_id: uuid.UUID,
    user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
) -> LessonSummaryResponse:
    now = datetime.now(timezone.utc)
    try:
        summary = session_service.complete_lesson_session(
            db, session_id=session_id, user_id=user.id, today=now.date(), now=now
        )
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc

    return LessonSummaryResponse(
        xp_earned=summary.xp_earned,
        current_streak=summary.current_streak,
        mastery_pct=summary.mastery_pct,
        topic_unlocked=summary.topic_unlocked,
    )
