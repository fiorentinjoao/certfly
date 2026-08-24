"""Ponto de entrada da API FastAPI — docs/system-design.md.

Rodar localmente: `uvicorn app.main:app --reload` (de dentro de backend/,
com o venv ativado).
"""

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.repository.db import Base, engine
from app.routers import answer, certifications, lesson, lesson_session, me, progress

app = FastAPI(title="CertFly API", version="0.1.0")

# CORS só importa pro frontend Flutter Web (apps nativos iOS/Android não
# mandam Origin, então nunca são bloqueados por isso). Sem
# CORS_ALLOWED_ORIGINS configurado, nenhuma origem é liberada — seguro por
# padrão em produção. Em dev, setar por ex.
# CORS_ALLOWED_ORIGINS=http://localhost:8850 (ou o IP da rede local, pra
# testar pelo navegador do celular).
_allowed_origins = [
    origin.strip()
    for origin in os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",")
    if origin.strip()
]
if _allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_allowed_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Cria as tabelas se ainda não existirem (idempotente). Suficiente pro MVP
# local/SQLite (RNF-06); contra o Postgres real do Supabase em produção,
# isso também roda na primeira subida — não há migration tool no MVP ainda.
Base.metadata.create_all(bind=engine)

app.include_router(me.router)
app.include_router(progress.router)
app.include_router(certifications.router)
app.include_router(lesson.router)
app.include_router(answer.router)
app.include_router(lesson_session.router)


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}
