"""Validação do JWT emitido pelo Supabase Auth (RF-01, RNF-04).

Usa o "JWT secret" compartilhado do projeto Supabase (HS256) — mais simples
que buscar JWKS via rede a cada request, adequado ao RNF-06 (solo dev, sem
infra extra a manter). Se o projeto migrar para chaves assimétricas
(JWKS), este módulo precisa trocar para validação via chave pública — fora
de escopo do MVP.
"""

import os
import uuid
from dataclasses import dataclass

import jwt
from dotenv import load_dotenv
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

load_dotenv()  # lê backend/.env se existir; não sobrescreve env vars já setadas

SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")

_security = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthenticatedUser:
    id: uuid.UUID
    email: str


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_security),
) -> AuthenticatedUser:
    """Dependency do FastAPI: exige `Authorization: Bearer <jwt_supabase>`
    em toda rota (ver docs/system-design.md, seção de endpoints)."""
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token ausente")

    if not SUPABASE_JWT_SECRET:
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "SUPABASE_JWT_SECRET não configurado no servidor",
        )

    try:
        payload = jwt.decode(
            credentials.credentials,
            SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token inválido") from exc

    try:
        user_id = uuid.UUID(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token sem 'sub' válido") from exc

    return AuthenticatedUser(id=user_id, email=payload.get("email", ""))
