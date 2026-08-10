"""Validação do JWT emitido pelo Supabase Auth (RF-01, RNF-04).

Projetos Supabase novos (chaves "publishable"/"secret", não mais
"anon"/"service_role") assinam o access token com uma chave assimétrica
(ES256) — verificamos contra o JWKS público do projeto
(`SUPABASE_URL/auth/v1/.well-known/jwks.json`), sem guardar segredo
nenhum aqui: `PyJWKClient` busca e cacheia as chaves de assinatura,
sem precisar de rede a cada request depois da primeira.

Fallback de dev: se `SUPABASE_JWT_SECRET` estiver setado e o token for
HS256 (o que `scripts/seed_dev.py` gera), valida com o segredo
compartilhado local em vez de bater no Supabase de verdade — só pra
iteração rápida offline. Em produção só `SUPABASE_URL` é setado, então
esse caminho nunca é usado lá.
"""

import os
import uuid
from dataclasses import dataclass
from functools import lru_cache

import jwt
from dotenv import load_dotenv
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

load_dotenv()  # lê backend/.env se existir; não sobrescreve env vars já setadas

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")  # dev-only, ver docstring do módulo

_security = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthenticatedUser:
    id: uuid.UUID
    email: str


@lru_cache(maxsize=1)
def _jwks_client() -> jwt.PyJWKClient:
    """Cliente JWKS memoizado — PyJWKClient já cacheia as chaves
    internamente por `kid`, então isso evita recriar o cache a cada request."""
    if not SUPABASE_URL:
        raise RuntimeError("SUPABASE_URL não configurado")
    return jwt.PyJWKClient(f"{SUPABASE_URL.rstrip('/')}/auth/v1/.well-known/jwks.json")


def _decode(token: str) -> dict:
    header = jwt.get_unverified_header(token)

    if header.get("alg") == "HS256" and SUPABASE_JWT_SECRET:
        return jwt.decode(token, SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")

    if not SUPABASE_URL:
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "SUPABASE_URL não configurado no servidor",
        )

    signing_key = _jwks_client().get_signing_key_from_jwt(token)
    return jwt.decode(
        token,
        signing_key.key,
        algorithms=[header.get("alg", "ES256")],
        audience="authenticated",
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_security),
) -> AuthenticatedUser:
    """Dependency do FastAPI: exige `Authorization: Bearer <jwt_supabase>`
    em toda rota (ver docs/system-design.md, seção de endpoints)."""
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token ausente")

    try:
        payload = _decode(credentials.credentials)
    except jwt.PyJWTError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token inválido") from exc

    try:
        user_id = uuid.UUID(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token sem 'sub' válido") from exc

    return AuthenticatedUser(id=user_id, email=payload.get("email", ""))
