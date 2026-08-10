# SPEC-001: Corrigir autorização em lesson-session e no gate de tópico

**Status:** Draft
**Autor:** João (com Claude) · **Data:** 2026-08-10
**Relacionado:** achados de auditoria de segurança de 2026-08-10 (memória
`certfly-security-debt`); primeira spec do projeto — inaugura o processo de
SDD descrito em `docs/specs/TEMPLATE.md`.

## 1. Contexto

Numa auditoria de segurança no backend (2026-08-10), dois problemas reais de
autorização foram encontrados e conscientemente adiados pelo dono do projeto
até agora. Retomando como item #1 da lista de foco em arquitetura/segurança
(o app é veículo de aprendizado de engenharia de software, não só produto —
ver `docs/product-spec.md`).

## 2. Problema

### 2.1 IDOR em `POST /lesson-session/{id}/complete`

- `app/repository/lesson_sessions.py:23` — `get(db, session_id)` busca a
  sessão só pela PK, sem filtrar por `user_id`.
- `app/services/session_service.py:36-49` — `complete_lesson_session()` usa
  `session.topic_id` e marca `completed_at`/`xp_earned` **sem nunca conferir
  que `session.user_id == user_id`** (o `user_id` que vem do JWT, via
  `get_current_app_user`).

**Impacto**: qualquer usuário autenticado que descubra (ou adivinhe — são
UUIDs v4, então na prática só "descubra") o `session_id` de outra pessoa
pode completar a sessão dela: grava um `xp_earned` calculado com o
`user_id` do ATACANTE mas associado à sessão da VÍTIMA, e dispara a
avaliação de desbloqueio de tópico usando o `topic_id` da vítima. Não é
capaz de roubar o XP em si (o `xp_earned` é somado a partir dos `attempts`
do próprio atacante), mas corrompe o estado da sessão da vítima e pode
destravar um tópico dela indevidamente.

### 2.2 Gate de tópico não é aplicado no servidor

- `app/services/lesson_service.py:28-49` — `start_lesson()` monta uma lição
  a partir de `topic_id` **sem checar se esse tópico está desbloqueado**
  pra esse usuário.
- `GET /certification/{id}/progress` (via `progress_service.py:45`) já
  devolve `unlocked: false` pros tópicos travados — ou seja, o cliente sabe
  perfeitamente quais `topic_id` estão bloqueados, e nada impede chamar
  `POST /topic/{id}/lesson` direto com um deles.

**Impacto**: o gate de 80% de domínio (RF-09, o mecanismo central do
produto — é o que diferencia "trilha real" de "banco de questões solto") é
hoje só uma UI que esconde botões. Qualquer cliente HTTP (não precisa nem
ser malicioso — um bug de frontend já bastaria) pula a trilha inteira.

**Por que isso importa mais que o normal aqui**: o backend fala com Postgres
via SQLAlchemy direto (não pelo client do Supabase com RLS) — então
Row Level Security do Postgres provavelmente não se aplica, e essa
autorização em código é a **única** linha de defesa pra ambos os casos.

## 3. Requisitos

**Funcionais**
- `complete_lesson_session` só deve completar sessões pertencentes ao
  usuário autenticado; qualquer outra tentativa falha de forma indistinguível
  de "sessão não existe" (não confirmar/negar a existência de sessões de
  terceiros).
- `start_lesson` só deve gerar lição pra tópicos desbloqueados do usuário
  autenticado, usando **a mesma regra** de desbloqueio já usada em
  `GET /certification/{id}/progress` (ponto de entrada = primeiro tópico do
  primeiro domínio; senão, precisa de `UserTopicProgress.unlocked`).

**Não-funcionais**
- Sem duplicar a lógica de "tópico está desbloqueado?" — hoje ela só existe
  dentro de `progress_service.get_certification_progress` (variável local
  `is_entry_point`/`unlocked`, `progress_service.py:40-46`); extrair pra um
  lugar único, usado nos dois pontos (leitura de progresso E gate de
  escrita), pra não correr risco de as duas regras divergirem com o tempo.
- Teste de regressão específico pra cada bug (não só "endpoint funciona"),
  pra esses dois cenários nunca voltarem sem barulho.

## 4. Modelo de ameaça

| | Sessão (2.1) | Gate (2.2) |
|---|---|---|
| Atacante | Usuário autenticado comum (não precisa de privilégio nenhum) | Usuário autenticado comum, ou até um bug honesto no frontend |
| Pré-condição | Conhecer/adivinhar um `session_id` alheio (UUID v4 — só via vazamento, não é enumerável) | Conhecer um `topic_id` bloqueado (trivial — vem do próprio `GET /progress`) |
| Ganho do atacante | Corromper estado de progresso de outro usuário; destravar tópico da vítima fora de hora | Pular a mecânica central de gate do produto pra si mesmo |
| Confidencialidade em risco? | Não deve revelar se o `session_id` pertence a outro usuário (por isso 404, não 403) | Não — o `topic_id` já é público pro próprio usuário via `/progress` |

## 5. Design / Abordagem

### 5.1 Módulo novo: `app/services/topic_gate.py`

Extrai a regra de desbloqueio pra um único lugar:

```python
def is_unlocked(db: Session, user_id: UUID, topic_id: UUID) -> bool:
    """Mesma regra usada em GET /certification/{id}/progress: o tópico está
    desbloqueado se for o ponto de entrada da trilha (1º tópico do 1º
    domínio) OU se já tiver sido explicitamente destravado (>=80% de
    domínio no tópico anterior — ver core-loop-srs.md)."""
    topic_with_domain = catalog.get_topic_with_domain(db, topic_id)
    if topic_with_domain is None:
        raise ValueError(f"topic {topic_id} não encontrado")
    topic, domain = topic_with_domain

    is_entry_point = domain.order == 1 and topic.order == 1
    if is_entry_point:
        return True

    progress = lesson_sessions.get_topic_progress(db, user_id, topic_id)
    return progress.unlocked
```

Precisa de uma função nova em `catalog.py` (`get_topic_with_domain`) — hoje
só existe `get_domains_with_topics` (lista tudo de uma vez, não busca 1
tópico). `progress_service.py` passa a chamar `topic_gate.is_unlocked`
também, eliminando a duplicação.

### 5.2 Fix do IDOR (`session_service.complete_lesson_session`)

```python
session = lesson_sessions.get(db, session_id)
if session is None or session.user_id != user_id:
    raise ValueError(f"lesson_session {session_id} não encontrada")
```

Mantém a mensagem genérica ("não encontrada") pros dois casos — sessão
inexistente e sessão de outro usuário viram a mesma resposta (404), pra não
vazar a existência de sessões alheias. O router já mapeia `ValueError` →
404, então nenhuma mudança é necessária em `lesson_session.py` (router).

### 5.3 Fix do gate (`lesson_service.start_lesson`)

```python
if not topic_gate.is_unlocked(db, user_id, topic_id):
    raise PermissionError(f"topic {topic_id} está bloqueado para este usuário")
```

Diferente do caso da sessão: aqui **não** faz sentido esconder como 404 —
o usuário já sabe que o tópico existe (veio de `/progress`), só não tem
acesso ainda. É um 403 Forbidden de verdade. Isso exige:
- Uma exceção distinta de `ValueError` (`PermissionError`, nativa do
  Python, ou uma exceção própria — a decidir na revisão) pro router
  conseguir diferenciar "não encontrado" (404) de "bloqueado" (403).
- `app/routers/lesson.py` hoje **não tem** `try/except` nenhum ao redor da
  chamada — precisa adicionar, igual ao padrão já usado em
  `lesson_session.py`.

### Alternativas consideradas

| Alternativa | Prós | Contras | Descartada porque |
|---|---|---|---|
| Checar `unlocked` só no service, sem extrair pra módulo novo (duplicar a regra em vez de compartilhar) | Menos arquivos novos, mudança mais isolada | Regra de negócio central do produto (RF-09) fica em 2 lugares — divergência silenciosa é questão de tempo | Viola o requisito não-funcional explícito da spec (não duplicar) |
| Aplicar RLS no Postgres em vez de checagem em código | Defesa em profundidade real (2ª camada) | Backend usa SQLAlchemy direto, não o client do Supabase — teria que reconstruir a conexão pra passar pelo PostgREST/RLS, mudança bem maior que o escopo desta spec | Fora de escopo aqui; vale uma spec própria depois se quiser essa camada extra |
| 403 genérico pra ambos os bugs (sessão E gate) | Mais simples, uma exceção só | Vaza a existência de sessões de terceiros no caso do IDOR (diferença entre "não existe" e "existe mas não é sua" ajuda um atacante a enumerar) | Modelo de ameaça (seção 4) exige 404 indistinguível pro caso da sessão |

## 6. Plano de teste

Dois testes de regressão novos em `tests/integration/test_api.py`
(seguindo o padrão dos testes já existentes ali):

1. `test_complete_lesson_session_de_outro_usuario_retorna_404` — cria
   sessão com usuário A (via JWT A), tenta completar com JWT de usuário B,
   espera 404. Confirma que o `xp_earned`/`completed_at` da sessão **não**
   mudou (proteção efetiva, não só o código de status).
2. `test_start_lesson_em_topico_bloqueado_retorna_403` — usuário sem
   nenhum `UserTopicProgress` tenta `POST /topic/{id}/lesson` num tópico
   que não é ponto de entrada (ex: 2º tópico do 1º domínio), espera 403.
3. (regressão positiva) `test_start_lesson_no_ponto_de_entrada_funciona` —
   confirma que o 1º tópico do 1º domínio continua acessível sem
   `UserTopicProgress` nenhum — pra garantir que o fix não quebra o
   caso-base de usuário novo.

## 7. Notas de rollout

- Sem migração de dado — as duas mudanças são só validação adicional em
  código.
- **Quebra de contrato de API**: `POST /topic/{id}/lesson` num tópico
  bloqueado hoje devolve 500 (exceção não tratada); depois da mudança,
  devolve 403 com corpo de erro. Nenhum client (Flutter) depende do 500
  atual — na prática o app nunca chama isso pra tópico bloqueado porque a
  UI esconde o botão, então esse caminho só existe hoje pra ataque/bug.
