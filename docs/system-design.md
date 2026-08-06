# System Design — MVP

> Como os requisitos (`requirements.md`), o domínio (entidades) e o motor (`core-loop-srs.md`) viram um sistema de verdade: stack, schema, fluxo de dados e deploy.

## Stack

| Camada | Escolha | Por quê |
|---|---|---|
| Frontend | **Flutter** | App nativo iOS+Android com um código só — bate com RNF-08 (uso mobile-first, sessões curtas "no ônibus, no almoço") |
| API / motor | **FastAPI** (Python) | Aproveita o background forte do dono em Python/dados; motor de regras (SRS/mastery/gate) implementado como funções puras, testáveis com `pytest` sem subir banco (RNF-01) |
| Banco de dados | **Postgres (gerenciado pelo Supabase)** | Tier gratuito cobre o MVP (RNF-05); relacional encaixa bem no domínio, que é fortemente relacional |
| Autenticação | **Supabase Auth** | E-mail/senha + OAuth Google prontos, sem implementar do zero (RF-01) |
| Deploy da API | **Railway ou Fly.io** (free tier) | Simples de manter sozinho (RNF-06), sem infra própria a gerenciar |

## Arquitetura — visão geral

```
┌─────────────────────┐
│   App Flutter        │
│   (iOS / Android)     │
└──────────┬────────────┘
           │
           │ 1. Login/cadastro (e-mail/senha ou Google)
           ▼
┌─────────────────────┐
│   Supabase Auth       │  ← emite JWT
└──────────┬────────────┘
           │
           │ 2. Chamadas de API com JWT no header (Authorization: Bearer ...)
           ▼
┌─────────────────────────────────────┐
│   API FastAPI (Railway/Fly)           │
│                                         │
│   Routers → Services → Motor (puro)    │
│                     ↓                  │
│              Repository (SQLAlchemy)   │
└──────────┬──────────────────────────────┘
           │
           │ 3. Lê/escreve dados (conexão direta ao Postgres)
           ▼
┌─────────────────────┐
│  Postgres (Supabase)  │
└─────────────────────┘
```

O Flutter **nunca fala direto com o Postgres** — sempre via API. O Flutter fala com o Supabase Auth só pra autenticar (obter o JWT); todo o resto do fluxo (lições, respostas, progresso) passa pela API FastAPI, que valida o JWT do Supabase (via JWKS/secret compartilhado) pra identificar o usuário antes de qualquer operação.

## Estrutura interna da API (por que separar em camadas)

```
app/
├── routers/        # endpoints HTTP (FastAPI) — validação de request/response
├── services/        # orquestração: chama motor + repository
├── motor/            # lógica de negócio pura — SRS, mastery, gate, XP
│                      # ZERO import de banco/HTTP aqui — só dados de entrada/saída
├── repository/       # acesso a dados (SQLAlchemy), único lugar que fala com Postgres
└── models/           # schemas Pydantic (API) + modelos SQLAlchemy (banco)

tests/
├── unit/             # testa motor/ isolado — sem banco, sem mock pesado (RNF-01)
└── integration/      # testa routers/ + repository/ com banco de teste
```

Essa separação é o que permite TDD real no `motor/`: escrever o teste da fórmula de SM-2 (`core-loop-srs.md`) antes de qualquer linha de FastAPI ou SQL existir.

## Schema do banco (Postgres)

```sql
-- Catálogo de conteúdo (agnóstico de provedor)
CREATE TABLE provider (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL
);

CREATE TABLE certification (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES provider(id),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE domain (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  certification_id UUID NOT NULL REFERENCES certification(id),
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  weight_pct NUMERIC,
  "order" INT NOT NULL,
  UNIQUE (certification_id, slug)
);

CREATE TABLE topic (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  domain_id UUID NOT NULL REFERENCES domain(id),
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  "order" INT NOT NULL,
  UNIQUE (domain_id, slug)
);

CREATE TABLE question (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id UUID NOT NULL REFERENCES topic(id),
  prompt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft', -- draft | active | archived
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE choice (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID NOT NULL REFERENCES question(id),
  text TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  explanation TEXT NOT NULL
);

-- Usuário (id compartilhado com o Supabase Auth — auth.users.id)
CREATE TABLE app_user (
  id UUID PRIMARY KEY, -- = auth.users.id do Supabase
  email TEXT NOT NULL,
  total_xp INT NOT NULL DEFAULT 0,
  current_streak INT NOT NULL DEFAULT 0,
  longest_streak INT NOT NULL DEFAULT 0,
  last_active_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Estado de SRS por usuário+questão (muta a cada resposta)
CREATE TABLE user_question_state (
  user_id UUID NOT NULL REFERENCES app_user(id),
  question_id UUID NOT NULL REFERENCES question(id),
  repetition_count INT NOT NULL DEFAULT 0,
  ease_factor NUMERIC NOT NULL DEFAULT 2.5,
  interval_days INT NOT NULL DEFAULT 0,
  due_date DATE,
  last_reviewed_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, question_id)
);

-- Log imutável de cada resposta (histórico/analytics)
CREATE TABLE attempt (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id),
  question_id UUID NOT NULL REFERENCES question(id),
  choice_id UUID NOT NULL REFERENCES choice(id),
  is_correct BOOLEAN NOT NULL,
  xp_earned INT NOT NULL,
  answered_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Gate de desbloqueio por tópico
CREATE TABLE user_topic_progress (
  user_id UUID NOT NULL REFERENCES app_user(id),
  topic_id UUID NOT NULL REFERENCES topic(id),
  unlocked BOOLEAN NOT NULL DEFAULT false,
  unlocked_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, topic_id)
);

-- Sessões de lição completadas (alimenta o streak)
CREATE TABLE lesson_session (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id),
  topic_id UUID NOT NULL REFERENCES topic(id),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  xp_earned INT NOT NULL DEFAULT 0
);
```

> Nota: `% de domínio do tópico` **não é uma coluna** — é calculado on-demand a partir de `user_question_state` (decisão já registrada em `core-loop-srs.md`: evitar dado derivado dessincronizado). Se performance pedir, vira uma view materializada depois — não é decisão do MVP.

## Endpoints da API (MVP)

| Método | Rota | O que faz |
|---|---|---|
| `GET` | `/me` | Perfil do usuário logado (XP, streak) |
| `GET` | `/certification/{id}/progress` | Domínios/tópicos com % de domínio atual e status de desbloqueio |
| `POST` | `/topic/{id}/lesson` | Gera uma lição (8-10 questões: novas + revisão vencida) |
| `POST` | `/question/{id}/answer` | Registra resposta → roda o motor → atualiza `user_question_state`, grava `attempt`, soma XP |
| `POST` | `/lesson-session/{id}/complete` | Fecha a sessão, atualiza streak, recalcula gate do tópico |

Todas as rotas exigem `Authorization: Bearer <jwt_supabase>`.

## Fluxo ponta a ponta (recap)

Ver `README.md` → seção de arquitetura já discutida no chat: abrir lição → responder → motor atualiza SRS → grava attempt + soma XP → ao fim da lição recalcula % domínio → checa gate → atualiza streak.

## Deploy (MVP)

- **API**: Railway ou Fly.io, free tier, deploy via Git push (branch `main`)
- **Banco + Auth**: Supabase (já gerenciado, sem deploy manual)
- **App Flutter**: builds internos (TestFlight / APK direto) para validação com os primeiros usuários — publicação em loja fica para depois da validação, fora do escopo do MVP

## Decisões de domínio fechadas nesta etapa

- `Attempt` mantido separado de `UserQuestionState`: um é log imutável (analytics/auditoria), o outro é o estado mutável que o motor lê/escreve a cada resposta.
- `Topic` mantido como nível entre `Domain` e `Question`: é a granularidade da barra de mastery (ex: "BigQuery 70%" dentro do domínio "Storing Data").
