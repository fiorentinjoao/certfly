"""`GET /certifications` — lista as certificações disponíveis com a % de
domínio geral do usuário em cada uma (ver product-spec.md, decisão de
2026-08-10: MVP cobre 3 certificações, 1 por cloud)."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.models.entities import AppUser
from app.repository.db import get_db
from app.routers.deps import get_current_app_user
from app.routers.schemas import CertificationOverviewResponse
from app.services import certifications_service

router = APIRouter(tags=["certifications"])


@router.get("/certifications", response_model=list[CertificationOverviewResponse])
def list_certifications(
    user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
) -> list[CertificationOverviewResponse]:
    overviews = certifications_service.get_certifications_overview(
        db, user.id, today=datetime.now(timezone.utc).date()
    )
    return [
        CertificationOverviewResponse(
            id=overview.certification.id,
            name=overview.certification.name,
            slug=overview.certification.slug,
            provider_name=overview.provider.name,
            provider_slug=overview.provider.slug,
            overall_mastery_pct=overview.overall_mastery_pct,
        )
        for overview in overviews
    ]
