"""Testes de integração da camada de repository — contra SQLite real
(ver conftest.py), não mocks, pra pegar erros de mapeamento ORM<->entidade
e de query que testes unitários (que não tocam banco) não pegariam."""

import uuid
from datetime import date, datetime, timedelta, timezone

from app.repository import attempts, catalog, lesson_sessions, srs_state, users
from app.repository.orm_models import (
    CertificationORM,
    ChoiceORM,
    DomainORM,
    ProviderORM,
    QuestionORM,
    TopicORM,
)


def _seed_topic_with_one_question(db_session):
    """Monta Provider -> Certification -> Domain -> Topic -> Question -> Choice
    mínimo para os testes que dependem de catálogo."""
    provider = ProviderORM(id=uuid.uuid4(), name="Google Cloud", slug="gcp")
    certification = CertificationORM(
        id=uuid.uuid4(), provider_id=provider.id, name="PDE", slug="pde"
    )
    domain = DomainORM(
        id=uuid.uuid4(), certification_id=certification.id, name="Storing Data", slug="storing", order=1
    )
    topic = TopicORM(id=uuid.uuid4(), domain_id=domain.id, name="BigQuery", slug="bigquery", order=1)
    question = QuestionORM(id=uuid.uuid4(), topic_id=topic.id, prompt="...", status="active")
    choice = ChoiceORM(
        id=uuid.uuid4(),
        question_id=question.id,
        text="Resposta certa",
        is_correct=True,
        explanation="Porque sim",
    )
    db_session.add_all([provider, certification, domain, topic, question, choice])
    db_session.commit()
    return topic, question, choice


# --- users ---------------------------------------------------------------------


def test_get_or_create_user_e_idempotente(db_session):
    user_id = uuid.uuid4()

    first = users.get_or_create_user(db_session, user_id, "user@example.com")
    second = users.get_or_create_user(db_session, user_id, "user@example.com")

    assert first.id == second.id == user_id
    assert first.total_xp == 0


def test_add_xp_acumula(db_session):
    user_id = uuid.uuid4()
    users.get_or_create_user(db_session, user_id, "user@example.com")

    users.add_xp(db_session, user_id, 10)
    updated = users.add_xp(db_session, user_id, 3)

    assert updated.total_xp == 13


def test_update_streak_persiste_streak_e_last_active_date(db_session):
    user_id = uuid.uuid4()
    users.get_or_create_user(db_session, user_id, "user@example.com")

    updated = users.update_streak(db_session, user_id, new_streak=1, today=date(2026, 8, 9))

    assert updated.current_streak == 1
    assert updated.longest_streak == 1
    assert updated.last_active_date == date(2026, 8, 9)


# --- catalog ---------------------------------------------------------------------


def test_get_domains_with_topics_retorna_na_ordem(db_session):
    topic, _, _ = _seed_topic_with_one_question(db_session)
    domain_row = db_session.get(DomainORM, topic.domain_id)

    domains = catalog.get_domains_with_topics(db_session, domain_row.certification_id)

    assert len(domains) == 1
    domain_entity, topics = domains[0]
    assert domain_entity.slug == "storing"
    assert len(topics) == 1
    assert topics[0].slug == "bigquery"


def test_get_questions_with_choices(db_session):
    topic, question, choice = _seed_topic_with_one_question(db_session)

    result = catalog.get_questions_with_choices(db_session, [question.id])

    assert len(result) == 1
    question_entity, choices = result[0]
    assert question_entity.id == question.id
    assert len(choices) == 1
    assert choices[0].id == choice.id
    assert choices[0].is_correct is True


# --- srs_state ---------------------------------------------------------------------


def test_srs_state_save_e_get_or_default_fazem_roundtrip(db_session):
    from app.models.entities import UserQuestionState

    _, question, _ = _seed_topic_with_one_question(db_session)
    user_id = uuid.uuid4()

    default_state = srs_state.get_or_default(db_session, user_id, question.id)
    assert default_state.repetition_count == 0
    assert default_state.interval_days == 0

    new_state = UserQuestionState(
        user_id=user_id, question_id=question.id, repetition_count=1, ease_factor=2.5, interval_days=1
    )
    reviewed_at = datetime(2026, 8, 9, 12, 0, 0)
    saved = srs_state.save(db_session, new_state, last_reviewed_at=reviewed_at)

    assert saved.interval_days == 1
    assert saved.due_date == date(2026, 8, 10)

    fetched = srs_state.get_or_default(db_session, user_id, question.id)
    assert fetched.repetition_count == 1
    assert fetched.due_date == date(2026, 8, 10)


def test_count_questions_seen(db_session):
    from app.models.entities import UserQuestionState

    _, question, _ = _seed_topic_with_one_question(db_session)
    user_id = uuid.uuid4()

    assert srs_state.count_questions_seen(db_session, user_id, [question.id]) == 0

    srs_state.save(
        db_session,
        UserQuestionState(user_id=user_id, question_id=question.id, repetition_count=1, interval_days=1),
        last_reviewed_at=datetime.now(timezone.utc),
    )

    assert srs_state.count_questions_seen(db_session, user_id, [question.id]) == 1


# --- attempts / lesson_sessions --------------------------------------------------------


def test_record_attempt(db_session):
    topic, question, choice = _seed_topic_with_one_question(db_session)
    user_id = uuid.uuid4()

    attempt = attempts.record(
        db_session,
        user_id=user_id,
        question_id=question.id,
        choice_id=choice.id,
        is_correct=True,
        xp_earned=10,
        answered_at=datetime.now(timezone.utc),
    )

    assert attempt.is_correct is True
    assert attempt.xp_earned == 10


def test_lesson_session_create_e_complete(db_session):
    topic, _, _ = _seed_topic_with_one_question(db_session)
    user_id = uuid.uuid4()

    session = lesson_sessions.create(
        db_session, user_id=user_id, topic_id=topic.id, started_at=datetime.now(timezone.utc)
    )
    assert session.completed_at is None

    completed = lesson_sessions.complete(
        db_session, session.id, completed_at=datetime.now(timezone.utc), xp_earned=25
    )
    assert completed.completed_at is not None
    assert completed.xp_earned == 25


def test_topic_progress_comeca_bloqueado_e_unlock_topic_destrava(db_session):
    topic, _, _ = _seed_topic_with_one_question(db_session)
    user_id = uuid.uuid4()

    progress = lesson_sessions.get_topic_progress(db_session, user_id, topic.id)
    assert progress.unlocked is False

    unlocked = lesson_sessions.unlock_topic(
        db_session, user_id, topic.id, unlocked_at=datetime.now(timezone.utc)
    )
    assert unlocked.unlocked is True

    refetched = lesson_sessions.get_topic_progress(db_session, user_id, topic.id)
    assert refetched.unlocked is True
