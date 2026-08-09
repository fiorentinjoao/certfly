"""Entidades de domínio do CertFly — modelagem 1:1 com o schema Postgres
descrito em docs/system-design.md.

Contêineres de dados imutáveis (dataclasses), sem I/O e sem dependência de
banco/HTTP. A camada de persistência (SQLAlchemy, em repository/) e a de API
(Pydantic, em routers/) devem mapear PARA estas entidades, não o contrário —
este módulo é a fonte da verdade do formato do domínio.

Hierarquia de conteúdo, 100% agnóstica de provedor (docs/architecture-decisions.md):
    Provider → Certification → Domain → Topic → Question → Choice

Estado de progresso do usuário, separado do conteúdo:
    AppUser, UserQuestionState, Attempt, UserTopicProgress, LessonSession
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from uuid import UUID

# --- Catálogo de conteúdo (agnóstico de provedor) --------------------------


@dataclass(frozen=True)
class Provider:
    """Um provedor de certificações (Google Cloud, AWS, Azure...)."""

    id: UUID
    name: str
    slug: str


@dataclass(frozen=True)
class Certification:
    """Uma certificação de um provedor (ex: Professional Data Engineer)."""

    id: UUID
    provider_id: UUID
    name: str
    slug: str
    active: bool = True


@dataclass(frozen=True)
class Domain:
    """Um domínio do exame de uma certificação (ex: Storing Data)."""

    id: UUID
    certification_id: UUID
    name: str
    slug: str
    order: int
    weight_pct: float | None = None


@dataclass(frozen=True)
class Topic:
    """Um tópico dentro de um domínio — granularidade da barra de mastery."""

    id: UUID
    domain_id: UUID
    name: str
    slug: str
    order: int


@dataclass(frozen=True)
class Question:
    """Uma questão de um tópico."""

    id: UUID
    topic_id: UUID
    prompt: str
    status: str = "draft"  # draft | active | archived
    created_at: datetime | None = None


@dataclass(frozen=True)
class Choice:
    """Uma alternativa de uma questão, com a explicação didática (RF-04)."""

    id: UUID
    question_id: UUID
    text: str
    is_correct: bool
    explanation: str


# --- Usuário e progresso -----------------------------------------------------


@dataclass(frozen=True)
class AppUser:
    """Um usuário do CertFly. `id` compartilhado com `auth.users` do Supabase."""

    id: UUID
    email: str
    total_xp: int = 0
    current_streak: int = 0
    longest_streak: int = 0
    last_active_date: date | None = None
    created_at: datetime | None = None


@dataclass(frozen=True)
class UserQuestionState:
    """Estado de SRS de um par usuário-questão, na forma de persistência.

    Espelha `app.motor.srs.SRSState` (mesmos defaults: repetition_count=0,
    ease_factor=2.5, interval_days=0), acrescentando as chaves e timestamps
    que o motor deliberadamente não conhece (`due_date` é calculado pela
    camada de serviço somando `interval_days` à data atual — ver docstring
    de app/motor/srs.py — não pelo motor em si, para mantê-lo determinístico
    e testável sem mockar relógio).
    """

    user_id: UUID
    question_id: UUID
    repetition_count: int = 0
    ease_factor: float = 2.5
    interval_days: int = 0
    due_date: date | None = None
    last_reviewed_at: datetime | None = None


@dataclass(frozen=True)
class Attempt:
    """Log imutável de uma tentativa de resposta (histórico/analytics, RF-10)."""

    id: UUID
    user_id: UUID
    question_id: UUID
    choice_id: UUID
    is_correct: bool
    xp_earned: int
    answered_at: datetime | None = None


@dataclass(frozen=True)
class UserTopicProgress:
    """Gate de desbloqueio de um tópico para um usuário (RF-09)."""

    user_id: UUID
    topic_id: UUID
    unlocked: bool = False
    unlocked_at: datetime | None = None


@dataclass(frozen=True)
class LessonSession:
    """Uma sessão de lição — completá-la é o que alimenta o streak (RF-08)."""

    id: UUID
    user_id: UUID
    topic_id: UUID
    started_at: datetime | None = None
    completed_at: datetime | None = None
    xp_earned: int = 0
