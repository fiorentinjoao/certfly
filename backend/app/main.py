"""Ponto de entrada da API FastAPI — docs/system-design.md.

Rodar localmente: `uvicorn app.main:app --reload` (de dentro de backend/,
com o venv ativado).
"""

from fastapi import FastAPI

from app.repository.db import Base, engine
from app.routers import answer, certifications, lesson, lesson_session, me, progress

app = FastAPI(title="CertFly API", version="0.1.0")

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
