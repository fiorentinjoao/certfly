"""Modelos SQLAlchemy — mapeiam 1:1 o schema Postgres de docs/system-design.md.

Este é o único módulo que conhece o formato de tabela (nomes de coluna,
tipos, FKs). O resto do backend (motor, services, routers) trabalha com as
entidades puras de app/models/entities.py — a tradução ORM <-> entidade
acontece em repository/mappers.py.
"""

import uuid
from datetime import date, datetime, timezone

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.repository.db import Base

# --- Catálogo de conteúdo (agnóstico de provedor) --------------------------


class ProviderORM(Base):
    __tablename__ = "provider"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String, nullable=False)
    slug: Mapped[str] = mapped_column(String, unique=True, nullable=False)


class CertificationORM(Base):
    __tablename__ = "certification"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    provider_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("provider.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    slug: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class DomainORM(Base):
    __tablename__ = "domain"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    certification_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("certification.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    slug: Mapped[str] = mapped_column(String, nullable=False)
    weight_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    order: Mapped[int] = mapped_column("order", Integer, nullable=False)


class TopicORM(Base):
    __tablename__ = "topic"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    domain_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("domain.id"), nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    slug: Mapped[str] = mapped_column(String, nullable=False)
    order: Mapped[int] = mapped_column("order", Integer, nullable=False)


class QuestionORM(Base):
    __tablename__ = "question"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    topic_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("topic.id"), nullable=False)
    prompt: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="draft")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    choices: Mapped[list["ChoiceORM"]] = relationship(back_populates="question")


class ChoiceORM(Base):
    __tablename__ = "choice"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    question_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("question.id"), nullable=False
    )
    text: Mapped[str] = mapped_column(Text, nullable=False)
    is_correct: Mapped[bool] = mapped_column(Boolean, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)

    question: Mapped["QuestionORM"] = relationship(back_populates="choices")


# --- Usuário e progresso -----------------------------------------------------


class AppUserORM(Base):
    __tablename__ = "app_user"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)  # = auth.users.id (Supabase)
    email: Mapped[str] = mapped_column(String, nullable=False)
    total_xp: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    current_streak: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_active_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class UserQuestionStateORM(Base):
    __tablename__ = "user_question_state"

    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("app_user.id"), primary_key=True)
    question_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("question.id"), primary_key=True
    )
    repetition_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    ease_factor: Mapped[float] = mapped_column(Float, nullable=False, default=2.5)
    interval_days: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    last_reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class AttemptORM(Base):
    __tablename__ = "attempt"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("app_user.id"), nullable=False)
    question_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("question.id"), nullable=False
    )
    choice_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("choice.id"), nullable=False)
    is_correct: Mapped[bool] = mapped_column(Boolean, nullable=False)
    xp_earned: Mapped[int] = mapped_column(Integer, nullable=False)
    answered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class UserTopicProgressORM(Base):
    __tablename__ = "user_topic_progress"

    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("app_user.id"), primary_key=True)
    topic_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("topic.id"), primary_key=True)
    unlocked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    unlocked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class LessonSessionORM(Base):
    __tablename__ = "lesson_session"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("app_user.id"), nullable=False)
    topic_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("topic.id"), nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    xp_earned: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
