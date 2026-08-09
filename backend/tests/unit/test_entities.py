"""Testes das entidades de domínio — docs/system-design.md (schema Postgres).

Cobrem os invariantes de negócio expressos como defaults (o que um
usuário/questão/tópico novo "vale" antes de qualquer interação) e a
imutabilidade das entidades, não o mecanismo trivial de dataclass em si.
"""

import dataclasses
from uuid import uuid4

import pytest

from app.models.entities import (
    AppUser,
    Certification,
    Question,
    UserQuestionState,
    UserTopicProgress,
)
from app.motor.srs import SRSState


def test_certification_nasce_ativa_por_padrao():
    certification = Certification(
        id=uuid4(), provider_id=uuid4(), name="Professional Data Engineer", slug="pde"
    )

    assert certification.active is True


def test_question_nasce_como_rascunho_por_padrao():
    question = Question(id=uuid4(), topic_id=uuid4(), prompt="...")

    assert question.status == "draft"


def test_app_user_novo_comeca_zerado():
    user = AppUser(id=uuid4(), email="user@example.com")

    assert user.total_xp == 0
    assert user.current_streak == 0
    assert user.longest_streak == 0
    assert user.last_active_date is None


def test_user_topic_progress_novo_comeca_bloqueado():
    progress = UserTopicProgress(user_id=uuid4(), topic_id=uuid4())

    assert progress.unlocked is False
    assert progress.unlocked_at is None


def test_user_question_state_default_espelha_srs_state_do_motor():
    # UserQuestionState é a forma de persistência do mesmo estado que o
    # motor calcula em app.motor.srs.SRSState — os defaults compartilhados
    # não podem divergir, ou a primeira leitura do banco (via ORM) já nasce
    # inconsistente com o que o motor produziria para uma questão nova.
    persisted_default = UserQuestionState(user_id=uuid4(), question_id=uuid4())
    motor_default = SRSState()

    assert persisted_default.repetition_count == motor_default.repetition_count
    assert persisted_default.ease_factor == motor_default.ease_factor
    assert persisted_default.interval_days == motor_default.interval_days


@pytest.mark.parametrize(
    "entity",
    [
        Certification(id=uuid4(), provider_id=uuid4(), name="X", slug="x"),
        Question(id=uuid4(), topic_id=uuid4(), prompt="..."),
        AppUser(id=uuid4(), email="user@example.com"),
    ],
)
def test_entidades_sao_imutaveis(entity):
    with pytest.raises(dataclasses.FrozenInstanceError):
        entity.id = uuid4()
