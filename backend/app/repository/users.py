"""Acesso a dados de app_user — perfil, XP e streak."""

import uuid
from datetime import date

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.entities import AppUser
from app.repository import mappers
from app.repository.orm_models import AppUserORM


def get_user(db: Session, user_id: uuid.UUID) -> AppUser | None:
    row = db.get(AppUserORM, user_id)
    return mappers.app_user_to_entity(row) if row else None


def get_or_create_user(db: Session, user_id: uuid.UUID, email: str) -> AppUser:
    """Garante que existe um app_user para o id vindo do JWT do Supabase Auth.

    O Supabase Auth já validou a identidade — na primeira chamada
    autenticada de um usuário novo, criamos a linha correspondente aqui em
    vez de exigir um passo de "registro" separado no domínio da aplicação.

    Sujeito a corrida: o cliente frequentemente dispara mais de uma
    chamada autenticada em paralelo (ex: Home busca /me e /progress ao
    mesmo tempo) — as duas podem ver "usuário não existe" e tentar
    inserir. Em vez de impedir isso com lock, tratamos a 2ª inserção que
    perde a corrida como sucesso: dá rollback e busca a linha que a
    primeira já criou.
    """
    row = db.get(AppUserORM, user_id)
    if row is not None:
        return mappers.app_user_to_entity(row)

    row = AppUserORM(id=user_id, email=email)
    db.add(row)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        row = db.get(AppUserORM, user_id)
        if row is None:
            raise
    else:
        db.refresh(row)
    return mappers.app_user_to_entity(row)


def add_xp(db: Session, user_id: uuid.UUID, xp_delta: int) -> AppUser:
    row = db.get(AppUserORM, user_id)
    if row is None:
        raise ValueError(f"app_user {user_id} não encontrado")

    row.total_xp += xp_delta
    db.commit()
    db.refresh(row)
    return mappers.app_user_to_entity(row)


def update_streak(db: Session, user_id: uuid.UUID, *, new_streak: int, today: date) -> AppUser:
    row = db.get(AppUserORM, user_id)
    if row is None:
        raise ValueError(f"app_user {user_id} não encontrado")

    row.current_streak = new_streak
    row.longest_streak = max(row.longest_streak, new_streak)
    row.last_active_date = today
    db.commit()
    db.refresh(row)
    return mappers.app_user_to_entity(row)
