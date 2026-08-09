"""Configuração de conexão e sessão do banco (SQLAlchemy).

Aponta para o Postgres do Supabase em produção via a env var `DATABASE_URL`
(ver .env.example). Sem essa env var — como ao rodar a suíte de testes
localmente — cai para um arquivo SQLite: suficiente para o schema deste MVP
(RNF-06: solo dev, sem infra própria a manter) e evita exigir um Postgres
real só para rodar `pytest`.
"""

import os
from collections.abc import Iterator

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

load_dotenv()  # lê backend/.env se existir; não sobrescreve env vars já setadas

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./certfly.db")

# SQLite exige essa flag pra permitir uso entre threads diferentes (é o que
# o TestClient/uvicorn fazem); Postgres não precisa de connect_args nenhum.
_connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=_connect_args)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


class Base(DeclarativeBase):
    """Base declarativa de todos os modelos ORM (repository/orm_models.py)."""


def get_db() -> Iterator[Session]:
    """Dependency do FastAPI: uma sessão por request, sempre fechada ao final."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
