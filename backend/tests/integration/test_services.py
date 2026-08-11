"""Testes de integração da camada de services — motor + repository juntos,
contra SQLite real (ver conftest.py)."""

import uuid
from datetime import date, datetime, timedelta, timezone

from app.repository import users
from app.repository.orm_models import ChoiceORM, DomainORM, QuestionORM, TopicORM
from app.services import (
    answer_service,
    lesson_service,
    progress_service,
    session_service,
)

TODAY = date(2026, 8, 9)
NOW = datetime(2026, 8, 9, 12, 0, 0, tzinfo=timezone.utc)


def _new_user(db_session):
    user_id = uuid.uuid4()
    users.get_or_create_user(db_session, user_id, "user@example.com")
    return user_id


def _add_topic_after(db_session, topic, *, topic_order, n_questions=1):
    """Adiciona mais um tópico no MESMO domínio de `topic`, com `topic_order`
    maior — pra testar que completar `topic` destrava o tópico seguinte da
    trilha, não ele mesmo."""
    new_topic = TopicORM(
        id=uuid.uuid4(),
        domain_id=topic.domain_id,
        name="Next",
        slug=f"next-{uuid.uuid4()}",
        order=topic_order,
    )
    db_session.add(new_topic)
    for i in range(n_questions):
        question = QuestionORM(
            id=uuid.uuid4(), topic_id=new_topic.id, prompt=f"Q{i}", status="active"
        )
        db_session.add(question)
        db_session.add(
            ChoiceORM(
                id=uuid.uuid4(),
                question_id=question.id,
                text="Certa",
                is_correct=True,
                explanation="...",
            )
        )
    db_session.commit()
    return new_topic


# --- lesson_service ---------------------------------------------------------------


def test_start_lesson_traz_ate_lesson_size_questoes_novas(db_session, seed_topic):
    topic, questions = seed_topic(12)
    user_id = _new_user(db_session)

    lesson = lesson_service.start_lesson(db_session, user_id, topic.id, TODAY, NOW)

    assert len(lesson.questions) == lesson_service.LESSON_SIZE
    assert lesson.session.topic_id == topic.id
    assert lesson.session.completed_at is None


def test_start_lesson_prioriza_revisao_vencida_sobre_questoes_novas(
    db_session, seed_topic
):
    topic, questions = seed_topic(3)
    (due_question, due_correct, _), *_rest = questions
    user_id = _new_user(db_session)

    # Responde a primeira questão certo, deixando o intervalo vencer (due
    # no passado) antes de gerar a lição.
    answer_service.answer_question(
        db_session,
        user_id=user_id,
        question_id=due_question.id,
        choice_id=due_correct.id,
        now=NOW - timedelta(days=5),
    )

    lesson = lesson_service.start_lesson(db_session, user_id, topic.id, TODAY, NOW)

    lesson_question_ids = [lq.question.id for lq in lesson.questions]
    assert lesson_question_ids[0] == due_question.id


# --- answer_service ---------------------------------------------------------------


def test_responder_questao_nova_certo_da_10_xp_e_avanca_srs(db_session, seed_topic):
    topic, questions = seed_topic(1)
    question, correct_choice, _wrong_choice = questions[0]
    user_id = _new_user(db_session)

    result = answer_service.answer_question(
        db_session,
        user_id=user_id,
        question_id=question.id,
        choice_id=correct_choice.id,
        now=NOW,
    )

    assert result.is_correct is True
    assert result.xp_earned == 10

    user = users.get_user(db_session, user_id)
    assert user.total_xp == 10


def test_responder_questao_errado_nao_da_xp(db_session, seed_topic):
    topic, questions = seed_topic(1)
    question, _correct_choice, wrong_choice = questions[0]
    user_id = _new_user(db_session)

    result = answer_service.answer_question(
        db_session,
        user_id=user_id,
        question_id=question.id,
        choice_id=wrong_choice.id,
        now=NOW,
    )

    assert result.is_correct is False
    assert result.xp_earned == 0

    user = users.get_user(db_session, user_id)
    assert user.total_xp == 0


def test_segunda_resposta_certa_conta_como_revisao_e_da_3_xp(db_session, seed_topic):
    topic, questions = seed_topic(1)
    question, correct_choice, _wrong_choice = questions[0]
    user_id = _new_user(db_session)

    answer_service.answer_question(
        db_session,
        user_id=user_id,
        question_id=question.id,
        choice_id=correct_choice.id,
        now=NOW,
    )
    second = answer_service.answer_question(
        db_session,
        user_id=user_id,
        question_id=question.id,
        choice_id=correct_choice.id,
        now=NOW + timedelta(days=1),
    )

    assert second.xp_earned == 3

    user = users.get_user(db_session, user_id)
    assert user.total_xp == 13


# --- progress_service ---------------------------------------------------------------


def test_primeiro_topico_do_primeiro_dominio_comeca_destravado(db_session, seed_topic):
    topic, questions = seed_topic(5, domain_order=1, topic_order=1)
    user_id = _new_user(db_session)
    certification_id = _certification_id_of(db_session, topic)

    progress = progress_service.get_certification_progress(
        db_session, user_id, certification_id, TODAY
    )

    topic_progress = progress[0].topics[0]
    assert topic_progress.unlocked is True
    assert topic_progress.mastery_pct == 0.0  # nada respondido ainda


def test_mastery_reflete_questoes_ja_respondidas(db_session, seed_topic):
    topic, questions = seed_topic(2)
    question, correct_choice, _ = questions[0]
    user_id = _new_user(db_session)
    certification_id = _certification_id_of(db_session, topic)

    answer_service.answer_question(
        db_session,
        user_id=user_id,
        question_id=question.id,
        choice_id=correct_choice.id,
        now=NOW,
    )

    progress = progress_service.get_certification_progress(
        db_session, user_id, certification_id, today=NOW.date()
    )

    topic_progress = progress[0].topics[0]
    # 1 questão com p=1.0 (acabou de responder) + 1 nunca vista (p=0.0) = média 0.5
    assert topic_progress.mastery_pct == 0.5


def _certification_id_of(db_session, topic):
    from app.repository.orm_models import DomainORM

    domain = db_session.get(DomainORM, topic.domain_id)
    return domain.certification_id


# --- session_service ---------------------------------------------------------------


def test_completar_sessao_atualiza_streak_e_soma_xp(db_session, seed_topic):
    topic, questions = seed_topic(2)
    question, correct_choice, _ = questions[0]
    user_id = _new_user(db_session)

    lesson = lesson_service.start_lesson(db_session, user_id, topic.id, TODAY, NOW)
    answer_service.answer_question(
        db_session,
        user_id=user_id,
        question_id=question.id,
        choice_id=correct_choice.id,
        now=NOW,
    )

    summary = session_service.complete_lesson_session(
        db_session, session_id=lesson.session.id, user_id=user_id, today=TODAY, now=NOW
    )

    assert summary.xp_earned == 10
    assert summary.current_streak == 1

    user = users.get_user(db_session, user_id)
    assert user.current_streak == 1
    assert user.last_active_date == TODAY


def test_gate_destrava_topico_ao_atingir_80_por_cento_com_amostra_minima(
    db_session, seed_topic
):
    # pool de 5 questões -> min_questions_seen = ceil(5 * 8/15) = 3
    topic, questions = seed_topic(5)
    user_id = _new_user(db_session)

    lesson = lesson_service.start_lesson(db_session, user_id, topic.id, TODAY, NOW)
    for question, correct_choice, _wrong in questions[:3]:
        answer_service.answer_question(
            db_session,
            user_id=user_id,
            question_id=question.id,
            choice_id=correct_choice.id,
            now=NOW,
        )

    summary = session_service.complete_lesson_session(
        db_session, session_id=lesson.session.id, user_id=user_id, today=TODAY, now=NOW
    )

    # 3 questões com p=1.0 + 2 nunca vistas (p=0.0) = média 0.6 -> não destrava
    assert summary.mastery_pct == 0.6
    assert summary.topic_unlocked is False


def test_gate_nao_destrava_com_amostra_insuficiente_mesmo_com_100_por_cento(
    db_session, seed_topic
):
    # pool de 15 -> min_questions_seen = 8; responder só 1 não deve destravar
    # mesmo que a única respondida esteja com p=1.0 (mastery de 1 questão só,
    # sem contar as demais como parte da amostra ainda vista)
    topic, questions = seed_topic(15)
    question, correct_choice, _ = questions[0]
    user_id = _new_user(db_session)

    lesson = lesson_service.start_lesson(db_session, user_id, topic.id, TODAY, NOW)
    answer_service.answer_question(
        db_session,
        user_id=user_id,
        question_id=question.id,
        choice_id=correct_choice.id,
        now=NOW,
    )

    summary = session_service.complete_lesson_session(
        db_session, session_id=lesson.session.id, user_id=user_id, today=TODAY, now=NOW
    )

    assert summary.topic_unlocked is False


def test_gate_destrava_o_proximo_topico_nao_o_atual(db_session, seed_topic):
    # Regressão: completar um tópico com mastery/amostra suficiente devia
    # destravar o PRÓXIMO tópico da trilha — não o próprio tópico recém
    # completado (bug original: `unlock_topic` era chamado com
    # `session.topic_id`, o que nunca liberava nada novo).
    topic, questions = seed_topic(2)
    next_topic = _add_topic_after(db_session, topic, topic_order=2)
    user_id = _new_user(db_session)
    certification_id = _certification_id_of(db_session, topic)

    lesson = lesson_service.start_lesson(db_session, user_id, topic.id, TODAY, NOW)
    for question, correct_choice, _wrong in questions:
        answer_service.answer_question(
            db_session,
            user_id=user_id,
            question_id=question.id,
            choice_id=correct_choice.id,
            now=NOW,
        )

    summary = session_service.complete_lesson_session(
        db_session, session_id=lesson.session.id, user_id=user_id, today=TODAY, now=NOW
    )
    assert summary.topic_unlocked is True

    progress = progress_service.get_certification_progress(
        db_session, user_id, certification_id, today=TODAY
    )
    topics_by_id = {t.topic.id: t for domain in progress for t in domain.topics}
    assert topics_by_id[next_topic.id].unlocked is True


def test_gate_nao_destrava_nada_quando_e_o_ultimo_topico_da_trilha(
    db_session, seed_topic
):
    # Completar o último tópico da certificação não deve quebrar — só não
    # há próximo tópico pra destravar.
    topic, questions = seed_topic(2)
    user_id = _new_user(db_session)

    lesson = lesson_service.start_lesson(db_session, user_id, topic.id, TODAY, NOW)
    for question, correct_choice, _wrong in questions:
        answer_service.answer_question(
            db_session,
            user_id=user_id,
            question_id=question.id,
            choice_id=correct_choice.id,
            now=NOW,
        )

    summary = session_service.complete_lesson_session(
        db_session, session_id=lesson.session.id, user_id=user_id, today=TODAY, now=NOW
    )

    assert summary.topic_unlocked is True
