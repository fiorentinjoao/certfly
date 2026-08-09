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

    result: list[DomainProgress] = []
    for domain, topics in domains_with_topics:
        topic_progresses = []
        for topic in topics:
            snapshot = topic_mastery.compute(db, user_id, topic.id, today)
            persisted_progress = lesson_sessions.get_topic_progress(db, user_id, topic.id)

            # O primeiro tópico do primeiro domínio é o ponto de entrada da
            # trilha — sem isso, nenhum usuário novo teria algo destravado
            # pra começar (docs/core-loop-srs.md não cobre este caso-base
            # explicitamente; interpretação assumida aqui).
            is_entry_point = domain.order == 1 and topic.order == 1
            unlocked = persisted_progress.unlocked or is_entry_point

            topic_progresses.append(
                TopicProgress(topic=topic, mastery_pct=snapshot.mastery_pct, unlocked=unlocked)
            )
        result.append(DomainProgress(domain=domain, topics=topic_progresses))

    return result
