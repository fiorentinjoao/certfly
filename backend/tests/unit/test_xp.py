"""Testes do motor de XP e streak — docs/core-loop-srs.md, seção 4."""

from datetime import date

from app.motor.xp import xp_for_answer, update_streak

# --- xp_for_answer -------------------------------------------------------------


def test_acertar_questao_nova_da_10_xp():
    assert xp_for_answer(is_new_question=True, is_correct=True) == 10


def test_acertar_questao_em_revisao_da_3_xp():
    assert xp_for_answer(is_new_question=False, is_correct=True) == 3


def test_errar_questao_nova_nao_da_xp():
    assert xp_for_answer(is_new_question=True, is_correct=False) == 0


def test_errar_questao_em_revisao_nao_da_xp():
    assert xp_for_answer(is_new_question=False, is_correct=False) == 0


# --- update_streak ---------------------------------------------------------------


def test_primeira_licao_da_vida_comeca_streak_em_1():
    streak = update_streak(current_streak=0, last_active_date=None, today=date(2026, 8, 9))

    assert streak == 1


def test_licao_completada_ontem_incrementa_streak():
    streak = update_streak(
        current_streak=5, last_active_date=date(2026, 8, 8), today=date(2026, 8, 9)
    )

    assert streak == 6


def test_segunda_licao_no_mesmo_dia_nao_incrementa_streak():
    streak = update_streak(
        current_streak=6, last_active_date=date(2026, 8, 9), today=date(2026, 8, 9)
    )

    assert streak == 6


def test_gap_de_mais_de_um_dia_reinicia_streak_em_1():
    streak = update_streak(
        current_streak=6, last_active_date=date(2026, 8, 5), today=date(2026, 8, 9)
    )

    assert streak == 1
