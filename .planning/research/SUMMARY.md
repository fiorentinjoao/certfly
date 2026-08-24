# Project Research Summary

**Project:** CertFly
**Domain:** SRS-based technical certification study app (backend: FastAPI/SQLAlchemy; mobile: Flutter) — this research covers the SQLite→Supabase Postgres migration, authorization hardening, content scale-up, and lightweight SDD/TDD process adoption milestone
**Researched:** 2026-08-11
**Confidence:** MEDIUM-HIGH

## Executive Summary

CertFly is a solo-built "Duolingo for cloud data certifications" app with a working SRS/mastery core loop already implemented and tested. The current research milestone is not about new product features — it's about hardening the foundation before scaling content: migrating from SQLite to Supabase Postgres, closing IDOR-style authorization gaps found in two known endpoints (topic-unlock, lesson-session), expanding the question bank to 50–80 original questions per certification (AWS DEA-C01, GCP PDE, Azure DP-700) with full domain-blueprint coverage, and adopting SDD/TDD discipline in a way that fits a solo dev's pace rather than slowing it down.

The recommended approach keeps the stack as-is (FastAPI + SQLAlchemy 2.0 sync, psycopg3, no async speculative rewrite) and adds only what's needed: Alembic for schema version control (replacing `create_all()`), a reusable ownership-check dependency pattern for authorization (rather than ad-hoc `if` checks or a full RBAC library), a `contextvars`-based request-id seam for future observability (no logging/metrics libraries yet), and TDD scoped specifically to the Motor layer (SRS/mastery/XP pure functions) and auth/service logic — not to Flutter UI or scripts. Content work should add a `source_guide_version` / provenance field to the YAML schema before bulk authoring begins, since retrofitting per-question sourcing after 150–240 questions exist is expensive.

The key risks are all "silent until it isn't" failure modes: Supabase's transaction-mode pooler (port 6543) breaks SQLAlchemy prepared statements under concurrency but works fine in dev/single-request testing, so this must be caught via config (`statement_cache_size=0`, or direct connection on port 5432) and load-testing, not manual smoke tests. SQLite's permissive typing (UUID-as-text, loose booleans, naive datetimes) will surface as constraint violations only once real Postgres is running, so a Postgres-backed test tier (`testcontainers`) is necessary before the migration is considered done. Authorization must move from two one-off patches to a repository-layer `WHERE ... AND user_id = :user_id` convention enforced across all future ID-accepting endpoints, returning 404 rather than 403 to avoid leaking resource existence.

## Key Findings

### Recommended Stack

The stack is locked to the existing FastAPI + SQLAlchemy 2.0 sync engine — no move to async (asyncpg, pytest-asyncio) is warranted at this scale. Core additions are all schema/ops tooling, not new frameworks.

**Core technologies:**
- Alembic (>=1.16,<2.0): Schema version control — replaces `create_all()` as the ongoing migration mechanism, auto-generates versioned migrations from `Base.metadata`
- psycopg[binary] (>=3.2): Postgres driver (already pinned) — do NOT switch to asyncpg or psycopg2, app is fully sync
- Supabase direct connection (port 5432) + `QueuePool`: Recommended for the long-running backend process; Supavisor session-mode as IPv4-only fallback; avoid transaction-mode pooler (6543) for app traffic due to prepared-statement conflicts
- testcontainers[postgres] (>=4.0): Ephemeral Postgres for integration tests, to catch dialect-specific bugs (types, constraints, `ON CONFLICT`) that SQLite masks
- Reusable ownership-check `Depends()` pattern (e.g., `get_owned_lesson_session()`): Repository/dependency-layer authorization instead of scattered per-endpoint `if` checks or a full RBAC library
- Explicit `ENVIRONMENT=development` gate for HS256 JWT fallback: Prevents dev-only auth bypass from ever reaching production

### Expected Features

This milestone is primarily infrastructure/content hardening rather than new user-facing features, but FEATURES.md establishes standards for the content expansion work.

**Must have (table stakes):**
- Full official exam-blueprint domain/topic taxonomy per certification (blocks weight-proportional content allocation)
- 100% original question authorship (no scraped exam dumps — hard legal/ethical boundary, not a tradeoff)
- Scenario-based prompts with plausible distractors and per-choice explanations for all answers
- Minimum ~15 questions per topic / 50–80 per certification, weighted to match official exam blueprint percentages
- Source citation tied to official exam guides, with human QA review before publishing (no unreviewed bulk LLM generation — hard boundary)

**Should have (competitive differentiators):**
- Difficulty tagging per question (schema addition now, SRS motor integration deferred to later)
- Task-statement traceability (question → specific exam guide task statement)
- Distractor rationale categories (why each wrong answer is wrong, categorized)
- Cross-domain scenario questions once single-domain coverage is solid
- Versioned content changelog

**Defer (v2+):**
- Full exam simulations (explicitly out of scope per product-spec.md)
- Community/crowdsourced content (needs governance design first)
- Difficulty-aware SRS scheduling logic (author the tag now; wire into motor later)

### Architecture Approach

No new architectural layers are introduced — the milestone's thesis is "no new layers, only new discipline." Three additive changes land on top of the existing Motor / Repository / Router structure: a lightweight human-written spec layer (`docs/specs/`, checked against test acceptance criteria, never fed to code generators), Alembic-managed schema evolution, and a minimal `contextvars`-based request-id seam for future observability without adding any logging/metrics dependencies yet.

**Major components:**
1. **Motor** (`backend/app/motor/`) — Pure-function SRS scheduling, mastery %, XP logic; the primary and only mandatory TDD target this milestone
2. **Repository** (SQLAlchemy layer) — Connection string swap to Supabase only; interface unchanged; gains ownership-filtered queries (`AND user_id = :user_id`) as the authorization convention
3. **Alembic** — Schema version control, must land before or with the Postgres migration (retrofitting to an already-drifted schema requires a hand-written baseline)
4. **RequestContextMiddleware** — Starlette middleware binding `request_id` via `ContextVar`, paired with a stdlib `RequestIdFilter` for log correlation — the only observability groundwork this milestone

### Critical Pitfalls

1. **Supabase pooler breaks prepared statements under concurrency** — Use direct connection (port 5432) for the app or set `statement_cache_size=0`/`NullPool`; this fails silently in dev/single-request testing, so load-testing is required verification, not optional polish.
2. **SQLite's permissive typing masks Postgres constraint/type enforcement** — Audit `orm_models.py` for UUID-as-text, loose boolean coercion, naive datetimes; add a `testcontainers`-backed Postgres test tier and run the full suite against it before declaring the migration done.
3. **First Alembic revision auto-generated against an empty/diverged DB** — Explicitly decide the baseline (`alembic stamp head` for pre-existing schemas), and remove `create_all()` from app boot once Alembic is in place — leaving both active causes drift.
4. **One-off authorization patches don't generalize** — The two known fixes (topic-unlock, lesson-session ownership) must become a written repository-layer convention (`WHERE id = :id AND user_id = :user_id`, return 404 not 403) with a regression test per gap, applied to all future ID-accepting endpoints — not just the two patched ones.
5. **Content provenance drift during bulk authoring** — Add a `source_guide_version` field to the content schema *before* authoring the 150–240 new questions; retrofitting provenance after the fact requires an expensive full manual audit.
6. **Uniform TDD/SDD adoption stalls a solo dev** — Scope TDD strictly to backend business logic (Motor, auth, SRS/XP services); treat Flutter UI and scripts as test-after-or-never to avoid the mid-project TDD abandonment trap.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Postgres Migration Foundation
**Rationale:** Everything else (auth fixes verified against real constraints, content at scale, process discipline) depends on the database being on Postgres with schema version control in place first; retrofitting Alembic or fixing type drift later is far more expensive than doing it up front.
**Delivers:** Supabase Postgres connection (direct, port 5432), Alembic initialized with a reconciled baseline (`alembic stamp head` against existing schema), `create_all()` removed from app boot, `testcontainers`-backed Postgres integration test tier running the full suite.
**Uses:** Alembic, psycopg3, testcontainers[postgres], QueuePool/direct-connection stack elements from STACK.md
**Implements:** Alembic + Repository components from ARCHITECTURE.md
**Avoids:** Pitfalls 1 (pooler/prepared statements), 2 (type drift), 3 (Alembic baseline mismatch)

### Phase 2: Authorization Hardening
**Rationale:** With a stable Postgres foundation, close the IDOR-pattern security gap comprehensively rather than patch-by-patch — this is a security-critical, well-scoped unit of work best done before content/traffic scale increases exposure.
**Delivers:** Repository-layer ownership-check convention (`get_owned_*` dependency pattern) generalized from the two known fixes to all ID-accepting endpoints, regression tests per endpoint, 404-not-403 convention documented, `ENVIRONMENT` gate hardening HS256 fallback.
**Addresses:** Security posture required before FEATURES.md content expansion increases surface area
**Avoids:** Pitfall 4 (authorization pattern generalization)

### Phase 3: Content Scale-Up (Blueprint Taxonomy + Question Bank)
**Rationale:** Content authoring is high-volume (150–240 new questions) and depends on the taxonomy work being finished first (GCP 5.x and AWS domain 4 task statements are currently incomplete) — doing this before the schema/provenance field exists would require a costly retrofit.
**Delivers:** Completed domain/topic taxonomy per certification, `source_guide_version` provenance field added to content schema and loader (`scripts/seed_dev.py`), 50–80 SME-authored original questions per cert with per-choice explanations, human QA review pass, difficulty tags authored (motor integration deferred).
**Addresses:** All FEATURES.md table-stakes items; difficulty tagging and task-statement traceability differentiators
**Avoids:** Pitfall 5 (content provenance drift)

### Phase 4: SDD/TDD Process Adoption
**Rationale:** Process discipline is easiest to bed in once the riskier infrastructure/security work is stable — introducing it earlier risks slowing down the higher-priority migration and auth work; introducing it after content scale-up means specs can reference the now-larger, more mature codebase.
**Delivers:** `docs/specs/<feature>.md` convention established for new features, TDD applied retroactively/going-forward to Motor and auth/service layers only, `contextvars` request-id middleware + stdlib logging filter added as sole observability groundwork, written TDD-scope paragraph documenting the boundary (Motor/auth = test-first, Flutter/scripts = test-after).
**Implements:** Spec layer, RequestContextMiddleware, TDD-scoping architecture patterns from ARCHITECTURE.md
**Avoids:** Pitfall 6 (uniform TDD adoption stalling solo dev)

### Phase Ordering Rationale

- Infrastructure before security before content before process: each phase reduces risk for the next — an unstable DB makes auth testing unreliable, an insecure API makes scaling content riskier, and process discipline is cheapest to adopt on a codebase that has already stabilized.
- Alembic and the content provenance field are both "add now or pay a much higher retrofit cost later" items — both are sequenced as early as their dependencies allow (Alembic in Phase 1, provenance field at the start of Phase 3, before bulk authoring).
- The two "hard boundary" pitfalls (prepared statements, auth generalization) are addressed with dedicated verification steps (load-testing, regression tests) rather than folded silently into other phases, since both are described in PITFALLS.md as failing silently under normal dev/smoke testing.

### Research Flags

Needs research during planning:
- **Phase 1 (Postgres Migration):** Supabase pooler mode selection (direct vs. Supavisor session vs. transaction mode) has environment-specific tradeoffs (IPv6 egress vs. IPv4 add-on) that should be validated against the actual deployment target before finalizing connection config.
- **Phase 3 (Content Scale-Up):** GCP and AWS domain/task-statement trees are explicitly incomplete in `docs/content-plan.md` — completing them requires reviewing current official exam guides, which is close to a fresh research task per certification.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Authorization Hardening):** Repository-layer ownership-check pattern is already proven in the codebase (`session_service.py` + `catalog.py`); this is generalization of an existing pattern, not new research.
- **Phase 4 (SDD/TDD Process Adoption):** Spec-anchored documentation and scoped-TDD patterns are well-established software engineering practice with clear guidance already captured in ARCHITECTURE.md.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Grounded in official SQLAlchemy/Supabase/Alembic docs and the existing locked stack; low ambiguity since no new framework choices are involved |
| Features | MEDIUM-HIGH | Item-writing standards (PSI, ExamSoft, ASC) are cross-corroborated externally; CertFly-specific volume targets (50–80 Q/cert) and tooling choices are project judgment, not externally validated |
| Architecture | HIGH | Explicitly scoped to avoid speculative additions; patterns (spec-anchored docs, scoped TDD, request-id seam) are conservative and well-precedented; Supabase pooler/port guidance sourced from official docs |
| Pitfalls | HIGH | Grounded in first-party codebase audits plus official Supabase docs, GitHub issues, and established IDOR/TDD-anti-pattern guidance; recovery costs and phase mapping are explicit |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- GCP PDE domain 5.x and AWS DEA-C01 domain 4 task-statement trees are incomplete in `docs/content-plan.md` — must be finished before Phase 3 volume allocation work can be scoped precisely; treat as a research/documentation prerequisite inside Phase 3, not a blocker for earlier phases.
- Supabase connection mode (direct port 5432 vs. Supavisor session mode) depends on the deployment host's IPv6 support, which wasn't confirmed during research — validate against actual hosting choice at the start of Phase 1.
- No load-testing tooling/process currently exists to catch the prepared-statement pooler failure mode (Pitfall 1) — Phase 1 should explicitly include a lightweight concurrency/load check, not just functional integration tests.

## Sources

### Primary (HIGH confidence)
- Official SQLAlchemy 2.0 docs — connection pooling, `QueuePool`, sync engine patterns
- Official Supabase docs — Supavisor pooler modes, connection string formats, port 5432 vs 6543 guidance
- Official Alembic docs — autogenerate workflow, `stamp head` baseline reconciliation
- First-party codebase audit (`session_service.py`, `catalog.py`, `orm_models.py`) — existing ownership-check pattern, current type usage

### Secondary (MEDIUM confidence)
- PSI / ExamSoft / ASC item-writing standards — question-quality and distractor-design guidance
- Community posts and GitHub issues — Supabase pooler + SQLAlchemy prepared-statement failure reports
- TDD anti-pattern guidance (general software engineering sources) — scoped-TDD rationale for solo/small-team projects

### Tertiary (LOW confidence)
- CertFly-specific content volume targets (50–80 Q/cert, ~15 Q/topic minimum) — project judgment, not externally validated; treat as a starting assumption to revisit if authoring velocity or exam-blueprint review suggests otherwise

---
*Research completed: 2026-08-11*
*Ready for roadmap: yes*
