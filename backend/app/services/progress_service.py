"""Orquestra o progresso de uma certificação para um usuário (RF-02) —
`GET /certification/{id}/progress` em docs/system-design.md."""

import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy.orm import Session

from app.models import entities
from app.repository import catalog, lesson_sessions
from app.services import topic_mastery


@dataclass(frozen=True)
class TopicProgress:
    topic: entities.Topic
    mastery_pct: float
    unlocked: bool


@dataclass(frozen=True)
class DomainProgress:
    domain: entities.Domain
    topics: list[TopicProgress]


def get_certification_progress(
    db: Session, user_id: uuid.UUID, certification_id: uuid.UUID, today: date
) -> list[DomainProgress]:
    domains_with_topics = catalog.get_domains_with_topics(db, certification_id)

    # Uma query pra mastery de todos os tópicos da certificação, não uma
    # por tópico (topic_mastery.compute_many — ver docstring lá pro N+1
    # que isso evita).
    all_topic_ids = [
        topic.id for _domain, topics in domains_with_topics for topic in topics
    ]
    mastery_snapshots = topic_mastery.compute_many(db, user_id, all_topic_ids, today)

    result: list[DomainProgress] = []
    for domain, topics in domains_with_topics:
        topic_progresses = []
        for topic in topics:
            snapshot = mastery_snapshots[topic.id]
            persisted_progress = lesson_sessions.get_topic_progress(
                db, user_id, topic.id
            )

            # O primeiro tópico do primeiro domínio é o ponto de entrada da
            # trilha — sem isso, nenhum usuário novo teria algo destravado
            # pra começar (docs/core-loop-srs.md não cobre este caso-base
            # explicitamente; interpretação assumida aqui). Delega pra
            # catalog.is_entry_point_topic — mesma regra usada por
            # lesson_service.start_lesson, pra não divergir.
            is_entry_point = catalog.is_entry_point_topic(db, topic.id)
            unlocked = persisted_progress.unlocked or is_entry_point

            topic_progresses.append(
                TopicProgress(
                    topic=topic, mastery_pct=snapshot.mastery_pct, unlocked=unlocked
                )
            )
        result.append(DomainProgress(domain=domain, topics=topic_progresses))

    return result
