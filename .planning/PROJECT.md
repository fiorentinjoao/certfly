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
- ✓ 73 testes de unidade/integração no backend (pytest, SQLite real em testes de integração) — `backend/tests/`
- ✓ 2 dos 3 gaps de segurança do `CONCERNS.md` corrigidos e mesclados no `master` (PR #6): gate de unlock validado no servidor (`POST /topic/{id}/lesson` recusa tópico bloqueado com 403) + IDOR do lesson-session (ownership scoped)
- ✓ CORS restrito por `CORS_ALLOWED_ORIGINS` (era `*`) — mesclado no `master`
- ✓ CI no GitHub Actions (pytest + flutter analyze/test em todo PR) — mesclado no `master`
- ✓ Pipeline de content-gen (`.claude/skills/certfly-content-gen/`): gera perguntas embasadas em doc oficial do produto (fetch → draft → fact-check → merge script), nunca em exam dumps
- ✓ Tooling de autoria de perguntas resolvido (`scripts/merge_content_draft.py` + content-gen acima) — o item que estava em "Out of Scope" abaixo já foi endereçado

### Active

- [ ] **Conteúdo ainda abaixo da meta** de ~15 perguntas/tópico (`docs/content-plan.md`): GCP 43 (era 18, +25 nesta sessão, mas ainda faltam os domínios "Designing data processing systems" e "Maintaining and automating data workloads", sem nenhum tópico escrito), AWS 9, Azure 8. Decisão em aberto (recomendada, não travada com o dono ainda): focar só GCP pro lançamento do MVP em vez das 3 certs completas.
- [ ] **PR #7 aberto, não mesclado**: `fix: GCP entry-point gate bug + 25 grounded questions` — https://github.com/joaoffiorentin/certfly/pull/7. Contém um bug crítico corrigido (ver Key Decisions) + as 25 perguntas novas do GCP. CI verde, falta só o merge.
- [ ] Fallback de auth dev-only (HS256) em `backend/app/auth.py` — ainda não endereçado (3º gap do `CONCERNS.md`, os outros 2 já foram corrigidos)
- [ ] **E-mail de produção**: confirmação de e-mail foi desativada manualmente no painel do Supabase (só pra destravar teste local) — precisa de SMTP customizado (Resend/SendGrid) configurado e confirmação reativada antes do lançamento real
- [ ] **Google OAuth quebrado fora do desktop**: `_signInWithGoogle` em `login_screen.dart` usa `HttpServer.bind(InternetAddress.loopbackIPv4, ...)`, uma API de `dart:io` que não existe no Flutter Web — quebra sempre no navegador. Sem fluxo equivalente (deep link) implementado pro mobile ainda.
- [ ] Processo de SDD/TDD mais rígido daqui pra frente (specs antes de codar, testes antes/junto da implementação) — travar workflow, não reescrever o que já existe
- [ ] Conectar o backend a um projeto Supabase Postgres real (hoje só SQLite local via `DATABASE_URL` não setada, ver `backend/app/repository/db.py`)
- [ ] Deploy da API (Railway/Fly.io, ver `docs/system-design.md`) — ainda não feito
- [ ] `profile_screen.dart`: botão de trocar certificação sem ação (`onTap: null`), apesar do endpoint `GET /certifications` já existir
- [ ] N+1 queries no cálculo de mastery (`certifications_service`/`progress_service`) — não bloqueia lançamento, mas vai doer com uso real

### Out of Scope

- Hardening adicional do sistema de login/auth (além dos gaps de segurança listados) — já funciona (Google desktop + email via Supabase), fica pra um próximo ciclo
- Observabilidade em produção (logs estruturados, métricas, tracing) — mencionada como visão futura, mas não faz parte do escopo ativo agora

## Context

- Origem: dono é engenheiro de dados, estuda pra certificações Google Cloud, sentiu o material disponível fragmentado/denso/sem hábito. Ideia: Duolingo pra esse estudo.
- Restrições de partida: dev solo, background forte em dados/backend, mais fraco em frontend/UX, quer projeto "bem feito" (system design + TDD), não só "shippar rápido".
- Sem prazo fixo pra este ciclo — ritmo de side project, prioriza qualidade sobre velocidade.
- Documentação de produto já consolidada em `docs/` (market-research, product-spec, architecture-decisions, core-loop-srs, requirements, system-design, supabase-email-templates) — este roadmap não reabre essas decisões, constrói em cima delas.
- Codebase mapeado em `.planning/codebase/` (STACK, ARCHITECTURE, STRUCTURE, CONVENTIONS, TESTING, INTEGRATIONS, CONCERNS) em 2026-08-11.
- Um bug de gate de desbloqueio (`unlock_topic` destravava o tópico errado) foi encontrado e corrigido em sessão anterior, com testes de regressão — ver `backend/app/services/session_service.py` e `backend/app/repository/catalog.py::get_next_topic_id`.
- Sessão de 2026-08-24: 2 gaps de segurança corrigidos e mesclados (PR #6), CI adicionado, pipeline de content-gen criado e usado (+25 perguntas GCP), e um bug crítico novo encontrado e corrigido — `is_entry_point_topic` era hardcoded pra `domain.order == 1` literal; como o GCP numera domínios pela ordem do exam guide oficial (não sequencial a partir de 1), nenhum domínio tinha esse valor e **todo o GCP ficou intravável pra qualquer usuário** assim que o gate passou a ser validado no servidor. Fix + as 25 perguntas estão no PR #7 (aberto, não mesclado ainda).

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
| Migrar de SQLite local pra Supabase Postgres real entra no escopo ativo | Hoje nenhum dado de usuário/conteúdo sobrevive fora da máquina de dev — inviabiliza qualquer teste com usuário real fora do dono; decidido após discussão explícita sobre Firebase vs. Supabase confirmar que o schema é relacional e já pensado pra Postgres | — Pending |
| **[recomendado, não travado com o dono]** Lançar o MVP com 1 certificação só (GCP) em vez das 3 completas | Com ~30 perguntas somadas nas 3 certs antes desta sessão, nenhuma estava de fato pronta; a métrica de sucesso do MVP é retenção de streak 7+ dias, não amplitude de catálogo — 1 cert completa valida a hipótese mais rápido que 3 incompletas | — Pending confirmação |

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
*Last updated: 2026-08-24 — sessão de segurança (PR #6 mesclado), CI, content-gen pipeline e fix crítico de entry-point do GCP (PR #7 aberto)*
