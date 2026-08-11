# CertFly

## What This Is

"Duolingo para certificações técnicas de dados" — sessões diárias curtas, com repetição espaçada (SRS/mastery) e domínio por tópico, para quem estuda certificações de dados nas 3 principais clouds (Google Cloud, AWS, Azure). Side project solo de um engenheiro de dados que sentiu o material de estudo disponível fragmentado, denso e sem estrutura de hábito.

## Core Value

Um usuário estuda um pouco todo dia, com o motor de repetição espaçada garantindo que o que ele já viu não seja esquecido — se isso não segurar o hábito diário, o resto (volume de conteúdo, polish visual) não importa.

## Requirements

### Validated

- ✓ Motor de core loop (SRS binário tipo SM-2 + mastery por tópico + gate de desbloqueio 80%) — implementado e testado (`backend/app/motor/`)
- ✓ API FastAPI com 6 endpoints cobrindo os 5 casos de uso do MVP (lição, resposta, progresso, sessão, perfil) — `backend/app/routers/`
- ✓ Auth real via Supabase (JWT ES256 via JWKS) com login Google/email no Flutter — `backend/app/auth.py`, `frontend/lib/auth/`
- ✓ Frontend Flutter funcional (bottom nav, trilha real por domínio/tópico, tela de lição, resumo, perfil, recuperação de senha) — `frontend/lib/screens/`
- ✓ Modelagem de conteúdo agnóstica de provedor/certificação (`content/*.yaml` → seed loader) cobrindo 3 certificações (AWS DEA-C01, Azure DP-700, GCP PDE)
- ✓ 69 testes de unidade/integração no backend (pytest, SQLite real em testes de integração) — `backend/tests/`

### Active

- [ ] Conteúdo real expandido para 50-80 perguntas por certificação (hoje 8-15), fiel ao exam guide oficial de cada cloud (AWS, GCP, Azure)
- [ ] Processo de SDD/TDD mais rígido daqui pra frente (specs antes de codar, testes antes/junto da implementação) — travar workflow, não reescrever o que já existe
- [ ] Cobertura de testes ampliada além dos 69 atuais (motor, repository, services, API) — observabilidade (logs estruturados, métricas, tracing) fica só esboçada como fase futura, não implementada neste ciclo
- [ ] Correção dos 3 gaps de segurança já identificados no mapeamento do codebase (`.planning/codebase/CONCERNS.md`) + revisão geral de segurança:
  - Gate de desbloqueio de tópico não reforçado no backend (`POST /topic/{id}/lesson` inicia lição em tópico travado)
  - Falta checagem de ownership em `POST /lesson-session/{id}/complete`
  - Fallback de auth dev-only (HS256) em `backend/app/auth.py` — garantir que não vaza pra produção

### Out of Scope

- Hardening adicional do sistema de login/auth (além dos gaps de segurança acima) — já funciona (Google + email via Supabase), fica pra um próximo ciclo
- Tooling mais simples de autoria de perguntas (hoje é YAML manual) — vira gargalo real só quando o volume de conteúdo crescer mais; adiado pra depois deste ciclo
- Observabilidade em produção (logs estruturados, métricas, tracing) — mencionada como visão futura, mas não faz parte do escopo ativo agora
- Conectar a um projeto Supabase real além do já usado pra Auth (hoje roda contra SQLite local para dev/dados) — fora do escopo definido neste ciclo, não foi mencionado como bloqueador

## Context

- Origem: dono é engenheiro de dados, estuda pra certificações Google Cloud, sentiu o material disponível fragmentado/denso/sem hábito. Ideia: Duolingo pra esse estudo.
- Restrições de partida: dev solo, background forte em dados/backend, mais fraco em frontend/UX, quer projeto "bem feito" (system design + TDD), não só "shippar rápido".
- Sem prazo fixo pra este ciclo — ritmo de side project, prioriza qualidade sobre velocidade.
- Documentação de produto já consolidada em `docs/` (market-research, product-spec, architecture-decisions, core-loop-srs, requirements, system-design, supabase-email-templates) — este roadmap não reabre essas decisões, constrói em cima delas.
- Codebase mapeado em `.planning/codebase/` (STACK, ARCHITECTURE, STRUCTURE, CONVENTIONS, TESTING, INTEGRATIONS, CONCERNS) em 2026-08-11.
- Um bug de gate de desbloqueio (`unlock_topic` destravava o tópico errado) foi encontrado e corrigido nesta mesma sessão, com testes de regressão — ver `backend/app/services/session_service.py` e `backend/app/repository/catalog.py::get_next_topic_id`.

## Constraints

- **Tech stack**: Backend Python/FastAPI + SQLAlchemy; frontend Flutter (dev target Linux, suporte Android/iOS); Supabase Auth/Postgres — não é escopo trocar stack neste ciclo.
- **Timeline**: Sem prazo fixo — side project solo, ritmo próprio.
- **Fonte de conteúdo**: Perguntas novas devem ser ancoradas no exam guide oficial de cada certificação (AWS, GCP, Azure), não em fontes de terceiros sem verificação.
- **Escopo solo**: Um único desenvolvedor — roadmap deve gerar fases executáveis sequencialmente sem depender de paralelismo de equipe.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Conteúdo, arquitetura/processo e testes são bloqueadores deste ciclo; login/auth hardening e tooling de autoria ficam em backlog | Login já funciona; tooling de autoria só vira gargalo com mais volume — foco no que trava o produto ganhar substância e robustez agora | — Pending |
| Segurança entra como bloqueador (não backlog) | 3 gaps concretos já identificados no mapeamento do codebase — correção barata comparada ao risco de deixar pra depois | — Pending |
| Meta de conteúdo: 50-80 perguntas por certificação, fiel ao exam guide oficial | Cobertura razoável dos domínios sem virar pesquisa infinita; ancorado em fonte oficial evita conteúdo errado/desatualizado | — Pending |
| Arquitetura/TDD/SDD: foco em processo daqui pra frente, não reescrever código já existente | Motor de core loop já nasceu com TDD e está testado; ganho maior está em travar disciplina pros próximos ciclos, não retrabalho | — Pending |
| Observabilidade fica só esboçada como fase futura no roadmap | Testes têm prioridade real agora; observabilidade em produção não é urgente sem usuários reais ainda | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-11 after initialization*
