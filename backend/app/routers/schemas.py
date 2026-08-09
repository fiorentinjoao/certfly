"""Schemas Pydantic de request/response da API — formato de fio (wire
format), separado tanto das entidades de domínio (app/models/entities.py)
quanto dos modelos ORM (app/repository/orm_models.py). Cada camada muda por
razões diferentes; misturar os três acopla API pública a detalhe de banco.
"""

import uuid

from pydantic import BaseModel


class MeResponse(BaseModel):
    id: uuid.UUID
    email: str
    total_xp: int
    current_streak: int
    longest_streak: int


class TopicProgressResponse(BaseModel):
    id: uuid.UUID
    name: str
    slug: str
    mastery_pct: float
    unlocked: bool


class DomainProgressResponse(BaseModel):
    id: uuid.UUID
    name: str
    slug: str
    topics: list[TopicProgressResponse]


class LessonChoiceResponse(BaseModel):
    """Alternativa SEM `is_correct`/`explanation` — não pode vazar a
    resposta certa antes do usuário responder (RF-04)."""

    id: uuid.UUID
    text: str


class LessonQuestionResponse(BaseModel):
    id: uuid.UUID
    prompt: str
    choices: list[LessonChoiceResponse]


class LessonResponse(BaseModel):
    session_id: uuid.UUID
    questions: list[LessonQuestionResponse]


class AnswerRequest(BaseModel):
    choice_id: uuid.UUID


class ChoiceExplanationResponse(BaseModel):
    """Alternativa COM `is_correct`/`explanation` — só devolvida depois de
    responder (RF-04)."""

    id: uuid.UUID
    text: str
    is_correct: bool
    explanation: str


class AnswerResponse(BaseModel):
    is_correct: bool
    xp_earned: int
    choices: list[ChoiceExplanationResponse]


class LessonSummaryResponse(BaseModel):
    """RF-11: resumo ao fim da lição."""

    xp_earned: int
    current_streak: int
    mastery_pct: float
    topic_unlocked: bool
