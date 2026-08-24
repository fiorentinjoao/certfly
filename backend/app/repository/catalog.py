"""Acesso a dados do catálogo de conteúdo — domínios, tópicos, questões e
alternativas. Somente leitura: o catálogo é escrito por um processo de
autoria de conteúdo (fora do escopo do MVP), não pela API de estudo."""

import uuid

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import entities
from app.repository import mappers
from app.repository.orm_models import (
    ChoiceORM,
    CertificationORM,
    DomainORM,
    ProviderORM,
    QuestionORM,
    TopicORM,
)


def get_active_certifications(
    db: Session,
) -> list[tuple[entities.Certification, entities.Provider]]:
    """Certificações ativas + seu provedor, ordenadas por provedor então
    nome — base do endpoint GET /certifications (RF-02 estendido pra
    multi-certificação, ver docs/product-spec.md, decisão de 2026-08-10)."""
    rows = db.execute(
        select(CertificationORM, ProviderORM)
        .join(ProviderORM, CertificationORM.provider_id == ProviderORM.id)
        .where(CertificationORM.active.is_(True))
        .order_by(ProviderORM.name, CertificationORM.name)
    ).all()
    return [
        (
            mappers.certification_to_entity(cert_row),
            mappers.provider_to_entity(provider_row),
        )
        for cert_row, provider_row in rows
    ]


def get_topic_ids_for_certification(
    db: Session, certification_id: uuid.UUID
) -> list[uuid.UUID]:
    """Todos os `topic_id` de uma certificação, direto (sem passar pelos
    domínios) — usado pra calcular a % de domínio geral da certificação."""
    return list(
        db.scalars(
            select(TopicORM.id)
            .join(DomainORM, TopicORM.domain_id == DomainORM.id)
            .where(DomainORM.certification_id == certification_id)
        ).all()
    )


def get_domains_with_topics(
    db: Session, certification_id: uuid.UUID
) -> list[tuple[entities.Domain, list[entities.Topic]]]:
    """Domínios de uma certificação, cada um com seus tópicos (RF-02)."""
    domain_rows = db.scalars(
        select(DomainORM)
        .where(DomainORM.certification_id == certification_id)
        .order_by(DomainORM.order)
    ).all()

    result = []
    for domain_row in domain_rows:
        topic_rows = db.scalars(
            select(TopicORM)
            .where(TopicORM.domain_id == domain_row.id)
            .order_by(TopicORM.order)
        ).all()
        result.append(
            (
                mappers.domain_to_entity(domain_row),
                [mappers.topic_to_entity(t) for t in topic_rows],
            )
        )
    return result


def get_next_topic_id(db: Session, topic_id: uuid.UUID) -> uuid.UUID | None:
    """Próximo tópico na ordem da trilha, a partir de `topic_id` — usado
    pelo gate de desbloqueio (RF-09) pra saber qual tópico destravar quando
    o atual atinge mastery suficiente.

    "Próximo" é: o tópico seguinte (menor `order` maior que o atual) no
    mesmo domínio; se `topic_id` for o último tópico do domínio, o primeiro
    tópico (menor `order`) do próximo domínio da mesma certificação. `None`
    se `topic_id` for o último tópico do último domínio — não há para onde
    avançar.
    """
    current = db.get(TopicORM, topic_id)
    if current is None:
        return None

    next_in_domain = db.scalars(
        select(TopicORM)
        .where(TopicORM.domain_id == current.domain_id, TopicORM.order > current.order)
        .order_by(TopicORM.order)
        .limit(1)
    ).first()
    if next_in_domain is not None:
        return next_in_domain.id

    current_domain = db.get(DomainORM, current.domain_id)
    if current_domain is None:
        return None

    next_domain = db.scalars(
        select(DomainORM)
        .where(
            DomainORM.certification_id == current_domain.certification_id,
            DomainORM.order > current_domain.order,
        )
        .order_by(DomainORM.order)
        .limit(1)
    ).first()
    if next_domain is None:
        return None

    first_topic_of_next_domain = db.scalars(
        select(TopicORM)
        .where(TopicORM.domain_id == next_domain.id)
        .order_by(TopicORM.order)
        .limit(1)
    ).first()
    return (
        first_topic_of_next_domain.id
        if first_topic_of_next_domain is not None
        else None
    )


def is_entry_point_topic(db: Session, topic_id: uuid.UUID) -> bool:
    """Primeiro tópico do primeiro domínio de uma certificação — o único
    ponto de entrada da trilha que começa destravado por padrão (mesma
    regra usada em progress_service.get_certification_progress, pra não
    haver duas definições divergentes de "entry point").

    "Primeiro" é o MENOR `order` existente, não o valor literal 1: o
    conteúdo do GCP numera domínios pela ordem do exam guide oficial (ex:
    "Storing the data" é domínio 3 lá), então enquanto o domínio 1 não for
    escrito, nenhum domínio tem order == 1 — usar o literal deixaria a
    trilha inteira sem ponto de entrada."""
    topic = db.get(TopicORM, topic_id)
    if topic is None:
        return False
    domain = db.get(DomainORM, topic.domain_id)
    if domain is None:
        return False

    first_domain_order = db.scalar(
        select(func.min(DomainORM.order)).where(
            DomainORM.certification_id == domain.certification_id
        )
    )
    if domain.order != first_domain_order:
        return False

    first_topic_order = db.scalar(
        select(func.min(TopicORM.order)).where(TopicORM.domain_id == domain.id)
    )
    return topic.order == first_topic_order


def get_topic_question_ids(db: Session, topic_id: uuid.UUID) -> list[uuid.UUID]:
    """IDs de todas as questões ativas de um tópico — o "pool" para mastery/lição."""
    return list(
        db.scalars(
            select(QuestionORM.id).where(
                QuestionORM.topic_id == topic_id, QuestionORM.status == "active"
            )
        ).all()
    )


def get_question_ids_by_topics(
    db: Session, topic_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[uuid.UUID]]:
    """Igual a `get_topic_question_ids`, mas para vários tópicos numa única
    query — usado por topic_mastery.compute_many pra evitar 1 query por
    tópico ao calcular mastery de uma certificação inteira (N+1)."""
    if not topic_ids:
        return {}

    rows = db.execute(
        select(QuestionORM.topic_id, QuestionORM.id).where(
            QuestionORM.topic_id.in_(topic_ids), QuestionORM.status == "active"
        )
    ).all()

    result: dict[uuid.UUID, list[uuid.UUID]] = {topic_id: [] for topic_id in topic_ids}
    for topic_id, question_id in rows:
        result[topic_id].append(question_id)
    return result


def get_questions_with_choices(
    db: Session, question_ids: list[uuid.UUID]
) -> list[tuple[entities.Question, list[entities.Choice]]]:
    """Questões + alternativas, na MESMA ORDEM de `question_ids`.

    `WHERE id IN (...)` sem `ORDER BY` não garante nenhuma ordem — o
    resultado é reordenado explicitamente aqui porque quem chama depende da
    ordem de entrada carregar sentido (ex: lesson_service.start_lesson põe
    revisão vencida antes de questões novas; perder essa ordem no meio do
    caminho anula a priorização de RF-03).
    """
    if not question_ids:
        return []

    question_rows = db.scalars(
        select(QuestionORM).where(QuestionORM.id.in_(question_ids))
    ).all()
    questions_by_id = {row.id: row for row in question_rows}

    result = []
    for question_id in question_ids:
        question_row = questions_by_id.get(question_id)
        if question_row is None:
            continue

        choice_rows = db.scalars(
            select(ChoiceORM).where(ChoiceORM.question_id == question_row.id)
        ).all()
        result.append(
            (
                mappers.question_to_entity(question_row),
                [mappers.choice_to_entity(c) for c in choice_rows],
            )
        )
    return result


def get_choice(db: Session, choice_id: uuid.UUID) -> entities.Choice | None:
    row = db.get(ChoiceORM, choice_id)
    return mappers.choice_to_entity(row) if row else None


def get_question(db: Session, question_id: uuid.UUID) -> entities.Question | None:
    row = db.get(QuestionORM, question_id)
    return mappers.question_to_entity(row) if row else None
