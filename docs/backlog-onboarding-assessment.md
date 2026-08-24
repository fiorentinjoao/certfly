# Backlog: Auto-avaliação de conhecimento no onboarding

**Status:** Ideia capturada, não planejada ainda — mover pro Jira pessoal quando for priorizar.
**Capturado em:** 2026-08-17

## Ideia

Depois que o usuário cria a conta, fazer algumas perguntas pra entender o que
ele já domina em cada cloud (inicialmente AWS, GCP, Azure) — em vez de todo
mundo começar do zero igual, o app já entenderia o nível de cada um.

## Por que isso importa

Hoje (ver `README.md`) todo usuário novo começa com mastery 0% em tudo, só o
primeiro tópico de cada certificação desbloqueado. Alguém que já trabalha com
AWS no dia a dia passaria pelo mesmo básico que alguém completamente novo —
onboarding genérico pra um público que pode ter bagagem bem diferente.

## Decisões de produto em aberto (não travadas ainda)

Discussão começou mas foi interrompida — retomar isso antes de planejar:

### 1. Formato do questionário
- **Opção A (mais simples):** perguntas de autopercepção de nível por
  provedor — "Você já trabalhou com AWS?" / nível
  nenhum/iniciante/intermediário/avançado. Rápido, mas menos preciso
  (autoavaliação de nível técnico costuma ser enviesada).
- **Opção B (mais preciso, mais arriscado):** quiz diagnóstico com perguntas
  técnicas reais, reaproveitando o banco de questões já existente em
  `content/*.yaml`. Mais fiel ao nível real, mas alonga o onboarding logo na
  entrada (risco de abandono antes de completar o cadastro).

### 2. O que o resultado muda no app
- **Opção A (mais simples/seguro):** só recomenda qual das 3 certificações
  começar primeiro (ex: "você já usa AWS no trabalho" → sugere trilha AWS).
  Não mexe no motor de SRS/mastery/gate já testado ponta a ponta.
- **Opção B (mais poderoso, mais arriscado):** usa as respostas pra já
  destravar/pontuar tópicos que o usuário demonstrou dominar, pulando o
  básico pra quem já sabe. Mexe direto no motor de gate/mastery
  (`core_lib`/`app/motor/`), que hoje é uma peça já validada — precisa de
  cuidado extra pra não introduzir regressão.

## Onde isso mexe no código (mapeamento inicial, não definitivo)

- **Frontend:** novo fluxo de telas pós-signup, antes de cair no `MainShell`
  (ver `lib/main.dart` → `_AuthGate`, `lib/screens/login_screen.dart`)
- **Backend:** endpoint novo pra registrar respostas da autoavaliação;
  possível ajuste em `app/motor/mastery.py` e `app/repository/srs_state.py`
  se a Opção B (ajustar mastery inicial) for escolhida
- **Dados:** possível tabela nova pra guardar respostas do questionário
  (schema ainda não desenhado)

## Próximo passo

Quando for priorizar: retomar a discussão de produto (as duas decisões acima)
antes de qualquer plano técnico — são decisões que mudam bastante o escopo
técnico da feature.
