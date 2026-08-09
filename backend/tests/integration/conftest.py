"""Fixtures compartilhadas dos testes de integração.

Cada teste roda contra um SQLite em memória isolado (schema recriado do
zero), para não depender de um Postgres/Supabase real (ver
app/repository/db.py) e não vazar estado entre testes.
"""

import uuid

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.repository.db import Base
# Importa os modelos ORM só para registrá-los em Base.metadata antes do
# create_all — sem isso, nenhuma tabela seria criada.
from app.repository import orm_models  # noqa: F401
from app.repository.orm_models import (
    CertificationORM,
    ChoiceORM,
    DomainORM,
    ProviderORM,
    QuestionORM,
    TopicORM,
)


@pytest.fixture()
def db_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    session_local = sessionmaker(bind=engine, autocommit=False, autoflush=False)

    session = session_local()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def seed_topic(db_session):
    """Monta Provider -> Certification -> Domain -> Topic -> N questões
    (1 alternativa correta cada) e devolve uma função `factory(n_questions,
    *, domain_order=1, topic_order=1)` que retorna o TopicORM e a lista de
    QuestionORM criados — reaproveitável por qualquer teste que precise de
    catálogo populado."""

    def factory(n_questions: int, *, domain_order: int = 1, topic_order: int = 1):
        provider = ProviderORM(id=uuid.uuid4(), name="Google Cloud", slug=f"gcp-{uuid.uuid4()}")
        certification = CertificationORM(
            id=uuid.uuid4(), provider_id=provider.id, name="PDE", slug=f"pde-{uuid.uuid4()}"
        )
        domain = DomainORM(
            id=uuid.uuid4(),
            certification_id=certification.id,
            name="Storing Data",
            slug=f"storing-{uuid.uuid4()}",
            order=domain_order,
        )
        topic = TopicORM(
            id=uuid.uuid4(),
            domain_id=domain.id,
            name="BigQuery",
            slug=f"bigquery-{uuid.uuid4()}",
            order=topic_order,
        )
        db_session.add_all([provider, certification, domain, topic])

        questions = []
        for i in range(n_questions):
            question = QuestionORM(
                id=uuid.uuid4(), topic_id=topic.id, prompt=f"Questão {i}", status="active"
            )
            correct_choice = ChoiceORM(
                id=uuid.uuid4(),
                question_id=question.id,
                text="Certa",
                is_correct=True,
                explanation="...",
            )
            wrong_choice = ChoiceORM(
                id=uuid.uuid4(),
                question_id=question.id,
                text="Errada",
                is_correct=False,
                explanation="...",
            )
            db_session.add_all([question, correct_choice, wrong_choice])
            questions.append((question, correct_choice, wrong_choice))

        db_session.commit()
        return topic, questions

    return factory
