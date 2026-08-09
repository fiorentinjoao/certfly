"""Testes do motor de mastery — docs/core-loop-srs.md.

Regra:
  p(questão) = 0.5 ^ (dias_desde_ultima_revisao / interval_days)
  % domínio do tópico = média de p(questão) de todas as questões
  gate: mastery_pct >= 80% E questions_seen >= min_questions_seen
"""

from app.motor.mastery import (
    MASTERY_UNLOCK_THRESHOLD,
    is_topic_unlocked,
    probability_of_recall,
    topic_mastery_pct,
)

# --- probability_of_recall ---------------------------------------------------


def test_recall_logo_apos_revisar_e_maximo():
    p = probability_of_recall(interval_days=3, days_since_last_review=0)

    assert p == 1.0


def test_recall_no_exato_dia_do_intervalo_e_meio():
    p = probability_of_recall(interval_days=3, days_since_last_review=3)

    assert p == 0.5


def test_recall_no_dobro_do_intervalo_cai_para_um_quarto():
    p = probability_of_recall(interval_days=3, days_since_last_review=6)

    assert p == 0.25


def test_recall_de_questao_nunca_respondida_com_sucesso_e_zero():
    # interval_days == 0 é o estado inicial (SRSState()) e o estado pós-erro
    p = probability_of_recall(interval_days=0, days_since_last_review=0)

    assert p == 0.0


# --- topic_mastery_pct --------------------------------------------------------


def test_mastery_do_topico_e_a_media_das_probabilidades():
    mastery = topic_mastery_pct([1.0, 0.5, 0.0, 0.0])

    assert mastery == 0.375


def test_mastery_de_topico_sem_questoes_e_zero():
    assert topic_mastery_pct([]) == 0.0


def test_mastery_maxima_quando_todas_as_questoes_estao_frescas():
    assert topic_mastery_pct([1.0, 1.0, 1.0]) == 1.0


# --- is_topic_unlocked ---------------------------------------------------------


def test_topico_destrava_com_80_por_cento_e_amostra_minima():
    unlocked = is_topic_unlocked(
        mastery_pct=MASTERY_UNLOCK_THRESHOLD, questions_seen=8, min_questions_seen=8
    )

    assert unlocked is True


def test_topico_nao_destrava_abaixo_de_80_por_cento_mesmo_com_amostra_suficiente():
    unlocked = is_topic_unlocked(mastery_pct=0.79, questions_seen=15, min_questions_seen=8)

    assert unlocked is False


def test_topico_nao_destrava_com_amostra_pequena_mesmo_com_100_por_cento():
    # ex: acertou as 2 únicas questões vistas de um pool de 15 — não é "domínio"
    unlocked = is_topic_unlocked(mastery_pct=1.0, questions_seen=2, min_questions_seen=8)

    assert unlocked is False
