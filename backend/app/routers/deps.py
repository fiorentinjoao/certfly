"""Dependencies compostas do FastAPI, usadas pelos routers — combinam
app/auth.py (parsing de JWT puro) com a camada de repository (I/O)."""

from fastapi import Depends
from sqlalchemy.orm import Session

from app.auth import AuthenticatedUser, get_current_user
from app.models.entities import AppUser
from app.repository import users
from app.repository.db import get_db


def get_current_app_user(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AppUser:
    """Garante que o app_user existe (get_or_create) em QUALQUER rota
    autenticada — não só em /me. Sem isso, responder uma questão antes de
    nunca ter chamado /me falharia com "app_user não encontrado": as rotas
    não podem depender da ordem de chamadas do cliente.
    """
    return users.get_or_create_user(db, current_user.id, current_user.email)
