"""Motor de SRS (Spaced Repetition System) — SM-2 adaptado, binário.

Lógica de negócio pura: sem I/O, sem banco, sem relógio. Recebe o estado
atual de uma questão para um usuário + se ele acertou ou errou, devolve o
novo estado. `due_date` (quando a questão deve voltar) não é calculado
aqui — é responsabilidade da camada de serviço/repositório somar
`interval_days` à data atual, mantendo este módulo determinístico e
testável sem mockar relógio.

Regras completas: docs/core-loop-srs.md
"""

from dataclasses import dataclass

EASE_FACTOR_MIN = 1.3
EASE_FACTOR_STEP_CORRECT = 0.1
EASE_FACTOR_STEP_WRONG = 0.2


@dataclass(frozen=True)
class SRSState:
    """Estado de SRS de um par usuário-questão."""

    repetition_count: int = 0
    ease_factor: float = 2.5
    interval_days: int = 0


def apply_answer(state: SRSState, *, correct: bool) -> SRSState:
    """Aplica uma resposta (certa ou errada) e devolve o novo estado de SRS."""
    if correct:
        return _apply_correct_answer(state)
    return _apply_wrong_answer(state)


def _apply_correct_answer(state: SRSState) -> SRSState:
    repetition_count = state.repetition_count + 1

    if repetition_count == 1:
        interval_days = 1
    elif repetition_count == 2:
        interval_days = 3
    else:
        # Usa o ease_factor ANTES do incremento deste acerto — o intervalo
        # reflete o quão "fácil" a questão vinha sendo até aqui, não o
        # ajuste que este acerto ainda vai gerar pro próximo ciclo.
        interval_days = round(state.interval_days * state.ease_factor)

    ease_factor = max(EASE_FACTOR_MIN, state.ease_factor + EASE_FACTOR_STEP_CORRECT)

    return SRSState(
        repetition_count=repetition_count,
        ease_factor=ease_factor,
        interval_days=interval_days,
    )


def _apply_wrong_answer(state: SRSState) -> SRSState:
    ease_factor = max(EASE_FACTOR_MIN, state.ease_factor - EASE_FACTOR_STEP_WRONG)

    return SRSState(
        repetition_count=0,
        ease_factor=ease_factor,
        interval_days=0,
    )
