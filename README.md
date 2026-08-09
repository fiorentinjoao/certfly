# CertFly

> Duolingo para certificações técnicas — sessões diárias curtas, com repetição espaçada e domínio por tópico, para quem estuda para certificações (começando por Google Cloud).

Side project solo. O backend (motor de regras + API) está funcional e testado ponta a ponta contra SQLite local; falta conteúdo real (questões), conectar a um Supabase de verdade e o frontend Flutter.

## Status atual (2026-08-09)

| Etapa | Status |
|---|---|
| Ideia validada (potencial real, nicho defensável) | ✅ |
| Pesquisa de mercado e concorrência | ✅ |
| Spec de MVP fechado | ✅ |
| Premissa arquitetural travada (agnóstico de provedor) | ✅ |
| Requisitos funcionais e não funcionais (RF/RNF) | ✅ |
| System design (Flutter + FastAPI + Supabase, schema, endpoints) | ✅ |
| Modelagem de domínio (entidades) | ✅ |
| Motor do core loop (SRS + mastery + gate + XP/streak) | ✅ |
| Repository (SQLAlchemy) + services + API FastAPI (5 endpoints) | ✅ |
| Conteúdo real (questões de Google Cloud PDE) | ⏳ próximo passo |
| Supabase real conectado (hoje roda em SQLite local) | ⏳ próximo passo |
| Frontend Flutter | ⏳ não iniciado |

## Contexto

Origem do projeto: o dono é engenheiro de dados, estuda para certificações Google Cloud, e sente que o material disponível é fragmentado, denso, em inglês e sem estrutura de hábito. Ideia: um app estilo Duolingo que gamifica esse estudo.

Restrições de partida:
- Desenvolvedor solo (side project)
- Background forte em dados/backend, mais fraco em frontend/UX
- Quer projeto "bem feito": system design + TDD, não só "shippar rápido"
- Ambição inicial de MVP em ~1 mês (spec foi cortado agressivamente para caber nisso)

## Documentação

| Doc | O que tem |
|---|---|
| [`docs/market-research.md`](docs/market-research.md) | Tamanho de mercado, concorrentes (CloudLearn, Whizlabs, Tutorials Dojo), a ciência por trás do motor de repetição espaçada do Duolingo (HLR/SM-2/SuperMemo) |
| [`docs/product-spec.md`](docs/product-spec.md) | Spec de MVP consolidado: problema, hipótese, escopo de conteúdo, core loop, o que fica de fora, métrica de sucesso |
| [`docs/architecture-decisions.md`](docs/architecture-decisions.md) | Premissas arquiteturais travadas — modelagem 100% agnóstica de provedor/certificação |
| [`docs/core-loop-srs.md`](docs/core-loop-srs.md) | Motor de mastery e repetição espaçada (SM-2 adaptado) — fórmulas e decisões fechadas |
| [`docs/requirements.md`](docs/requirements.md) | Requisitos funcionais e não funcionais do MVP (RF/RNF) |
| [`docs/system-design.md`](docs/system-design.md) | Stack, arquitetura, schema do banco, endpoints e plano de deploy do MVP |

## Rodando o backend localmente

```bash
cd backend
uv venv .venv && uv pip install -e ".[dev]"   # ou: python3 -m venv .venv && pip install -e ".[dev]"

.venv/bin/python -m pytest                     # roda a suíte (unit + integration)
.venv/bin/uvicorn app.main:app --reload         # sobe a API em http://localhost:8000/docs
```

Sem `DATABASE_URL`/`SUPABASE_JWT_SECRET` configurados (ver `backend/.env.example`), a API sobe contra um SQLite local (`backend/certfly.db`) e qualquer rota autenticada responde 500 — suficiente para rodar a suíte de testes e para desenvolvimento do motor/repository, mas não pra bater na API de verdade sem um projeto Supabase.

### Estrutura do backend

```
backend/app/
├── motor/       # regras de negócio puras (SRS, mastery, XP/streak) — sem I/O
├── models/      # entidades de domínio (dataclasses) — app/models/entities.py
├── repository/  # SQLAlchemy: orm_models.py (schema), db.py (sessão), + 1 módulo por agregado
├── services/    # orquestra motor + repository pros 5 casos de uso do MVP
├── routers/     # endpoints FastAPI + schemas Pydantic de request/response
└── auth.py      # validação do JWT do Supabase Auth
```

## Roadmap imediato

1. Requisitos funcionais e não funcionais ✅
2. Modelagem de domínio (entidades) ✅
3. System design (stack, schema, endpoints, deploy) ✅
4. Motor completo + repository + services + API FastAPI ✅
5. Escrever conteúdo real (questões de Google Cloud PDE) — próximo passo
6. Conectar a um projeto Supabase real (hoje só SQLite local)
7. Frontend Flutter

## Nota sobre origem deste documento

Este conjunto de docs foi reconstruído a partir de uma conversa no Claude.ai em 2026-08-06, recuperada e organizada via Claude Code. Pode haver pequenas lacunas em trechos intermediários da conversa original que não foram totalmente recuperados — revise e ajuste livremente.
