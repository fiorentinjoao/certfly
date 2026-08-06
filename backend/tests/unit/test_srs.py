"""Testes do motor de SRS (SM-2 adaptado, binário) — docs/core-loop-srs.md.

Regra:
  Acertou: repetition_count += 1
    - repetition_count == 1 -> interval = 1
    - repetition_count == 2 -> interval = 3
    - repetition_count >= 3 -> interval = round(interval_anterior * EF)
    - EF = max(1.3, EF + 0.1)
  Errou: repetition_count = 0, interval = 0, EF = max(1.3, EF - 0.2)
"""

from app.motor.srs import SRSState, apply_answer


def test_estado_inicial_padrao_de_uma_questao_nunca_vista():
    state = SRSState()

    assert state.repetition_count == 0
    assert state.ease_factor == 2.5
    assert state.interval_days == 0


def test_primeiro_acerto_define_intervalo_de_1_dia():
    state = SRSState()

    new_state = apply_answer(state, correct=True)

    assert new_state.repetition_count == 1
    assert new_state.interval_days == 1


def test_segundo_acerto_consecutivo_define_intervalo_de_3_dias():
    state = SRSState(repetition_count=1, ease_factor=2.5, interval_days=1)

    new_state = apply_answer(state, correct=True)

    assert new_state.repetition_count == 2
    assert new_state.interval_days == 3


def test_terceiro_acerto_consecutivo_multiplica_intervalo_anterior_pelo_ease_factor():
    state = SRSState(repetition_count=2, ease_factor=2.5, interval_days=3)

    new_state = apply_answer(state, correct=True)

    assert new_state.repetition_count == 3
    assert new_state.interval_days == round(3 * 2.5)  # 8


def test_acertos_subsequentes_continuam_multiplicando_pelo_novo_ease_factor():
    # 4º acerto consecutivo, a partir do estado deixado pelo teste anterior
    state = SRSState(repetition_count=3, ease_factor=2.6, interval_days=8)

    new_state = apply_answer(state, correct=True)

    assert new_state.repetition_count == 4
    assert new_state.interval_days == round(8 * 2.6)  # 21


def test_acerto_aumenta_ease_factor_em_0_1():
    state = SRSState(repetition_count=1, ease_factor=2.5, interval_days=1)

    new_state = apply_answer(state, correct=True)

    assert new_state.ease_factor == 2.6


def test_erro_zera_repetition_count_e_intervalo():
    state = SRSState(repetition_count=4, ease_factor=2.6, interval_days=21)

    new_state = apply_answer(state, correct=False)

    assert new_state.repetition_count == 0
    assert new_state.interval_days == 0


def test_erro_reduz_ease_factor_em_0_2():
    state = SRSState(repetition_count=4, ease_factor=2.6, interval_days=21)

    new_state = apply_answer(state, correct=False)

    assert new_state.ease_factor == 2.4


def test_ease_factor_nunca_fica_abaixo_de_1_3_apos_erro():
    state = SRSState(repetition_count=1, ease_factor=1.35, interval_days=1)

    new_state = apply_answer(state, correct=False)

    assert new_state.ease_factor == 1.3


def test_ease_factor_respeita_piso_de_1_3_mesmo_partindo_de_um_estado_invalido():
    # Estado hipotético abaixo do piso — a fórmula deve corrigir, não propagar o erro
    state = SRSState(repetition_count=1, ease_factor=1.2, interval_days=1)

    new_state = apply_answer(state, correct=True)

    assert new_state.ease_factor == 1.3
