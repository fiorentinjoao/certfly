"""`GET /me` — perfil do usuário logado (RF-01)."""

from fastapi import APIRouter, Depends

from app.models.entities import AppUser
from app.routers.deps import get_current_app_user
from app.routers.schemas import MeResponse

router = APIRouter(tags=["me"])


@router.get("/me", response_model=MeResponse)
def get_me(user: AppUser = Depends(get_current_app_user)) -> MeResponse:
    return MeResponse(
        id=user.id,
        email=user.email,
        total_xp=user.total_xp,
        current_streak=user.current_streak,
        longest_streak=user.longest_streak,
    )
