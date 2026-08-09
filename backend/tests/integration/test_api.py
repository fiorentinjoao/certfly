"""Testes de integração da API FastAPI — TestClient ponta a ponta, com
`get_db` e `get_current_user` sobrescritos (SQLite em memória + usuário
fake), sem precisar de um SUPABASE_JWT_SECRET real (ver app/auth.py)."""

import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.auth import AuthenticatedUser, get_current_user
from app.main import app
from app.repository.db import Base, get_db
from app.repository.orm_models import (
    CertificationORM,
    ChoiceORM,
    DomainORM,
    ProviderORM,
    QuestionORM,
    TopicORM,
)

FAKE_USER_ID = uuid.uuid4()


@pytest.fixture()
def client():
    # StaticPool: uma única conexão compartilhada entre threads — o
    # TestClient roda os endpoints síncronos numa threadpool, e o pool
    # padrão de SQLite em memória (por thread) faria essa thread enxergar
    # um banco vazio, diferente do que a fixture acabou de popular.
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    session_local = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    session = session_local()

    def override_get_db():
        yield session

    def override_get_current_user():
        return AuthenticatedUser(id=FAKE_USER_ID, email="test@example.com")

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    with TestClient(app) as test_client:
        test_client._db_session = session  # exposto pros testes popularem o catálogo
        yield test_client

    app.dependency_overrides.clear()
    session.close()
    engine.dispose()


def _seed_topic_with_question(db):
    provider = ProviderORM(id=uuid.uuid4(), name="Google Cloud", slug="gcp")
    certification = CertificationORM(
        id=uuid.uuid4(), provider_id=provider.id, name="PDE", slug="pde"
    )
    domain = DomainORM(
        id=uuid.uuid4(), certification_id=certification.id, name="Storing", slug="storing", order=1
    )
    topic = TopicORM(id=uuid.uuid4(), domain_id=domain.id, name="BigQuery", slug="bigquery", order=1)
    question = QuestionORM(id=uuid.uuid4(), topic_id=topic.id, prompt="Pergunta?", status="active")
    correct = ChoiceORM(
        id=uuid.uuid4(), question_id=question.id, text="Certa", is_correct=True, explanation="Porque sim"
    )
    wrong = ChoiceORM(
        id=uuid.uuid4(), question_id=question.id, text="Errada", is_correct=False, explanation="Porque não"
    )
    db.add_all([provider, certification, domain, topic, question, correct, wrong])
    db.commit()
    return certification, topic, question, correct


def test_health():
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_me_sem_token_retorna_401():
    with TestClient(app) as client:
        response = client.get("/me")
    assert response.status_code == 401


def test_me_cria_usuario_na_primeira_chamada(client):
    response = client.get("/me")

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(FAKE_USER_ID)
    assert body["total_xp"] == 0
    assert body["current_streak"] == 0


def test_fluxo_completo_de_uma_licao(client):
    certification, topic, question, correct_choice = _seed_topic_with_question(client._db_session)

    # 1. progresso: tópico 1 do domínio 1 já vem destravado
    progress_response = client.get(f"/certification/{certification.id}/progress")
    assert progress_response.status_code == 200
    progress = progress_response.json()
    assert progress[0]["topics"][0]["unlocked"] is True
    assert progress[0]["topics"][0]["mastery_pct"] == 0.0

    # 2. gerar lição — NÃO deve vazar is_correct/explanation
    lesson_response = client.post(f"/topic/{topic.id}/lesson")
    assert lesson_response.status_code == 200
    lesson = lesson_response.json()
    assert len(lesson["questions"]) == 1
    assert "is_correct" not in lesson["questions"][0]["choices"][0]
    session_id = lesson["session_id"]

    # 3. responder certo — agora sim vem a explicação de cada alternativa
    answer_response = client.post(
        f"/question/{question.id}/answer", json={"choice_id": str(correct_choice.id)}
    )
    assert answer_response.status_code == 200
    answer = answer_response.json()
    assert answer["is_correct"] is True
    assert answer["xp_earned"] == 10
    assert any(c["is_correct"] for c in answer["choices"])

    # 4. fechar a sessão — resumo com XP, streak e mastery
    complete_response = client.post(f"/lesson-session/{session_id}/complete")
    assert complete_response.status_code == 200
    summary = complete_response.json()
    assert summary["xp_earned"] == 10
    assert summary["current_streak"] == 1

    # 5. /me reflete o XP e streak acumulados
    me_response = client.get("/me")
    me = me_response.json()
    assert me["total_xp"] == 10
    assert me["current_streak"] == 1
