"""`GET /certification/{id}/progress` — domínios/tópicos com % de domínio
e status de desbloqueio (RF-02)."""

import uuid
from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.models.entities import AppUser
from app.repository.db import get_db
from app.routers.deps import get_current_app_user
from app.routers.schemas import DomainProgressResponse, TopicProgressResponse
from app.services import progress_service

router = APIRouter(tags=["progress"])


@router.get(
    "/certification/{certification_id}/progress",
    response_model=list[DomainProgressResponse],
)
def get_progress(
    certification_id: uuid.UUID,
    user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
) -> list[DomainProgressResponse]:
    domains = progress_service.get_certification_progress(
        db, user.id, certification_id, today=date.today()
    )
    return [
        DomainProgressResponse(
            id=domain_progress.domain.id,
            name=domain_progress.domain.name,
            slug=domain_progress.domain.slug,
            topics=[
                TopicProgressResponse(
                    id=topic_progress.topic.id,
                    name=topic_progress.topic.name,
                    slug=topic_progress.topic.slug,
                    mastery_pct=topic_progress.mastery_pct,
                    unlocked=topic_progress.unlocked,
                )
                for topic_progress in domain_progress.topics
            ],
        )
        for domain_progress in domains
    ]
