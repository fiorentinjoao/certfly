"""Lista as certificações disponíveis com a % de domínio geral do usuário
em cada uma — `GET /certifications`. Decisão de 2026-08-10 (product-spec.md):
MVP passou a cobrir 3 certificações (1 por cloud), então a Home precisa de
um jeito de listar/trocar entre elas — antes só existia
`GET /certification/{id}/progress`, que já assume um ID conhecido.
"""

import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy.orm import Session

from app.models import entities
from app.repository import catalog
from app.services import topic_mastery


@dataclass(frozen=True)
class CertificationOverview:
    certification: entities.Certification
    provider: entities.Provider
    overall_mastery_pct: float


def get_certifications_overview(
    db: Session, user_id: uuid.UUID, today: date
) -> list[CertificationOverview]:
    certifications = catalog.get_active_certifications(db)

    result: list[CertificationOverview] = []
    for certification, provider in certifications:
        topic_ids = catalog.get_topic_ids_for_certification(db, certification.id)

        # % geral = média do mastery de cada tópico — mesmo cálculo por
        # tópico usado em GET /certification/{id}/progress (topic_mastery.
        # compute_many), só que agregado. Certificação sem tópico nenhum
        # ainda (conteúdo não escrito) mostra 0%, não erro.
        if topic_ids:
            snapshots = topic_mastery.compute_many(db, user_id, topic_ids, today)
            mastery_values = [snapshots[topic_id].mastery_pct for topic_id in topic_ids]
            overall = sum(mastery_values) / len(mastery_values)
        else:
            overall = 0.0

        result.append(
            CertificationOverview(
                certification=certification,
                provider=provider,
                overall_mastery_pct=overall,
            )
        )

    return result
