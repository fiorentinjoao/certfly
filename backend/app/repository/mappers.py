"""Tradução entre modelos ORM (repository/orm_models.py) e entidades de
domínio puras (app/models/entities.py). É a única camada que conhece os
dois formatos ao mesmo tempo — services e motor nunca importam orm_models
diretamente.
"""

from app.models import entities
from app.repository import orm_models as orm


def provider_to_entity(row: orm.ProviderORM) -> entities.Provider:
    return entities.Provider(id=row.id, name=row.name, slug=row.slug)


def certification_to_entity(row: orm.CertificationORM) -> entities.Certification:
    return entities.Certification(
        id=row.id,
        provider_id=row.provider_id,
        name=row.name,
        slug=row.slug,
        active=row.active,
    )


def domain_to_entity(row: orm.DomainORM) -> entities.Domain:
    return entities.Domain(
        id=row.id,
        certification_id=row.certification_id,
        name=row.name,
        slug=row.slug,
        order=row.order,
        weight_pct=row.weight_pct,
    )


def topic_to_entity(row: orm.TopicORM) -> entities.Topic:
    return entities.Topic(
        id=row.id, domain_id=row.domain_id, name=row.name, slug=row.slug, order=row.order
    )


def question_to_entity(row: orm.QuestionORM) -> entities.Question:
    return entities.Question(
        id=row.id,
        topic_id=row.topic_id,
        prompt=row.prompt,
        status=row.status,
        created_at=row.created_at,
    )


def choice_to_entity(row: orm.ChoiceORM) -> entities.Choice:
    return entities.Choice(
        id=row.id,
        question_id=row.question_id,
        text=row.text,
        is_correct=row.is_correct,
        explanation=row.explanation,
    )


def app_user_to_entity(row: orm.AppUserORM) -> entities.AppUser:
    return entities.AppUser(
        id=row.id,
        email=row.email,
        total_xp=row.total_xp,
        current_streak=row.current_streak,
        longest_streak=row.longest_streak,
        last_active_date=row.last_active_date,
        created_at=row.created_at,
    )


def user_question_state_to_entity(row: orm.UserQuestionStateORM) -> entities.UserQuestionState:
    return entities.UserQuestionState(
        user_id=row.user_id,
        question_id=row.question_id,
        repetition_count=row.repetition_count,
        ease_factor=row.ease_factor,
        interval_days=row.interval_days,
        due_date=row.due_date,
        last_reviewed_at=row.last_reviewed_at,
    )


def attempt_to_entity(row: orm.AttemptORM) -> entities.Attempt:
    return entities.Attempt(
        id=row.id,
        user_id=row.user_id,
        question_id=row.question_id,
        choice_id=row.choice_id,
        is_correct=row.is_correct,
        xp_earned=row.xp_earned,
        answered_at=row.answered_at,
    )


def user_topic_progress_to_entity(row: orm.UserTopicProgressORM) -> entities.UserTopicProgress:
    return entities.UserTopicProgress(
        user_id=row.user_id,
        topic_id=row.topic_id,
        unlocked=row.unlocked,
        unlocked_at=row.unlocked_at,
    )


def lesson_session_to_entity(row: orm.LessonSessionORM) -> entities.LessonSession:
    return entities.LessonSession(
        id=row.id,
        user_id=row.user_id,
        topic_id=row.topic_id,
        started_at=row.started_at,
        completed_at=row.completed_at,
        xp_earned=row.xp_earned,
    )
