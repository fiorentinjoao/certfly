# Architecture Research

**Domain:** Solo-developer FastAPI+SQLAlchemy+Flutter side project — SDD/TDD process adoption + SQLite→Supabase Postgres migration with future-observability groundwork
**Researched:** 2026-08-11
**Confidence:** MEDIUM-HIGH (process patterns are well-established community consensus; Supabase-pooling specifics are HIGH, sourced from official docs)

## Standard Architecture

### System Overview

Certfly already has the right shape for this milestone — it does **not** need new layers, only new *discipline* around the existing ones, plus a swapped persistence backend.

```
┌─────────────────────────────────────────────────────────────────────┐
│  SPEC LAYER (new, process-only — no runtime component)               │
│  docs/specs/<feature>.md  — 1 file per feature, written BEFORE code  │
├─────────────────────────────────────────────────────────────────────┤
│  ROUTERS (FastAPI)        — unchanged responsibility                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐                 │
│  │ lesson  │  │ answer  │  │progress │  │  ...    │                 │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘                 │
│       │            │            │            │                      │
│  + RequestContextMiddleware (new, thin) → binds request_id           │
├───────┴────────────┴────────────┴────────────┴───────────────────────┤
│  SERVICES (orchestration)  — unchanged responsibility                │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  lesson_service / answer_service / session_service            │   │
│  └─────────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────────┤
│  MOTOR (pure)             — unchanged, TDD's primary target          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                           │
│  │   srs    │  │  mastery │  │    xp    │                           │
│  └──────────┘  └──────────┘  └──────────┘                           │
├─────────────────────────────────────────────────────────────────────┤
│  REPOSITORY (SQLAlchemy)  — swap engine only, interface unchanged    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  db.py: engine = create_engine(DATABASE_URL, ...)              │  │
│  └─────────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────────┤
│  Supabase Postgres (pooler, port 6543, transaction mode)             │
│  + Alembic (new — replaces create_all-on-boot)                       │
└─────────────────────────────────────────────────────────────────────┘
```

Two changes are additive to the existing stack: a **spec layer** (pure process, markdown files, zero runtime footprint) and a **request-context seam** (one small middleware + logging config change) that costs almost nothing today but is the load-bearing hook for observability later.

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `docs/specs/<feature>.md` | Freeze intent + acceptance criteria before code is written, for features where ambiguity is real | Short markdown: problem, API contract, acceptance criteria, edge cases. No tooling, no generation pipeline. |
| `RequestContextMiddleware` | Attach `request_id` (and later `user_id`, `trace_id`) to every request via `contextvars` | Starlette `BaseHTTPMiddleware`, sets a `ContextVar`, injects into logging filter |
| Structured log formatter | Emit one JSON line per log event, request_id included | `structlog` or stdlib `logging` + custom `Formatter`, no external log shipper needed now |
| `backend/app/repository/db.py` | Own the SQLAlchemy `Engine`/`SessionLocal`, swap SQLite→Postgres transparently | `create_engine(DATABASE_URL, pool_pre_ping=True, pool_recycle=1800)`; driver decided by URL |
| `alembic/versions/` | Own schema evolution as an ordered, reviewable history — replaces `create_all()` | `alembic revision --autogenerate` + manual review, `alembic upgrade head` on deploy |
| Motor tests (`tests/unit/`) | Primary TDD surface — pure functions, no DB, fast enough to run on every save | `pytest`, no fixtures needed beyond plain dataclasses |
| Integration tests (`tests/integration/`) | Verify service+repository+router wiring against a real (test) Postgres | `pytest` + `TestClient` + a disposable Supabase/local Postgres schema |

## Recommended Project Structure

```
certfly/
├── docs/
│   ├── specs/                      # NEW — one .md per non-trivial feature, written before code
│   │   ├── _TEMPLATE.md
│   │   └── topic-unlock-gate.md
│   └── architecture-decisions.md   # existing — ADRs, unchanged pattern
├── backend/
│   ├── alembic/                    # NEW — replaces create_all() as source of schema truth
│   │   ├── env.py
│   │   └── versions/
│   ├── app/
│   │   ├── middleware/              # NEW — thin, 1-2 files
│   │   │   └── request_context.py   # binds request_id ContextVar, nothing else yet
│   │   ├── motor/                   # unchanged — pure, TDD-first
│   │   ├── repository/
│   │   │   └── db.py                # unchanged interface, env-driven DATABASE_URL
│   │   ├── services/                # unchanged
│   │   └── routers/                 # unchanged
│   └── tests/
│       ├── unit/                    # motor-only, no DB — fast, run on every change
│       └── integration/             # service+repo+router, against Postgres test schema
└── frontend/                        # unchanged this milestone
```

### Structure Rationale

- **`docs/specs/` lives outside `backend/`:** specs are cross-cutting (frontend+backend), and keeping them as plain markdown (not a DSL, not a generator input) keeps the cost near-zero — they are a communication artifact for future-you, not a build step.
- **`alembic/` inside `backend/`, next to `app/`:** standard SQLAlchemy convention; keeps migration history colocated with the models it describes, and keeps `create_all()` fully removable in one PR.
- **`middleware/` as its own small package:** even though it starts as one file (request_id binding), separating it from `routers/` signals "cross-cutting concern," which is exactly where logging/metrics/tracing hooks will attach later without touching business code.

## Architectural Patterns

### Pattern 1: Spec-anchored, not spec-generated development

**What:** Write a short markdown spec *before* code for any feature with real ambiguity (new endpoint, new business rule, anything touching the SRS/mastery motor or auth). The spec is a human artifact you write and refer back to — not an input to a code-generation pipeline. For trivial, unambiguous changes (typo fix, styling tweak, adding a well-understood CRUD field), skip the spec and go straight to TDD.
**When to use:** Any change where you'd otherwise have to re-derive "what does correct behavior mean here" mid-implementation — i.e., most motor/service-layer changes and anything touching the 3 known security gaps.
**Trade-offs:** Costs 10-20 minutes upfront; saves far more by preventing mid-implementation scope drift and gives you a artifact to test against later. Skipping it for genuinely trivial changes avoids the classic solo-dev failure mode of "process become its own project."

**Example spec skeleton** (`docs/specs/_TEMPLATE.md`):
```markdown
# Spec: <feature name>

## Problem
[1-2 sentences: what's broken or missing]

## Contract
- Endpoint / function signature
- Inputs / outputs (types)
- Error cases

## Acceptance Criteria
- [ ] Given X, when Y, then Z
- [ ] ...

## Out of Scope
[explicitly excluded, to prevent scope creep]
```

### Pattern 2: TDD at the motor boundary, not everywhere

**What:** Strict red-green-refactor TDD is applied to `motor/` (pure functions: SRS scheduling, mastery %, XP) because it's cheap to test (no DB, no I/O, runs in milliseconds) and it's where correctness bugs are most damaging (silently wrong spaced-repetition math erodes the whole product's value proposition). For `repository/` and `routers/`, write the integration test *after* a first working pass, then lock it in — full TDD there has lower ROI because the "test" is mostly asserting SQLAlchemy/FastAPI wiring works, not business logic.
**When to use:** Motor changes → spec (if non-trivial) → failing unit test → implementation → refactor. Repository/router changes → implement → integration test → refactor.
**Trade-offs:** This is *not* "TDD everywhere," which is the pattern that burns out solo devs on side projects. It concentrates rigor where bugs are expensive and skips ceremony where tests would just restate the framework's own guarantees.

**Example:**
```python
# tests/unit/test_srs.py — written FIRST, before implementation
def test_correct_answer_after_lapse_resets_interval_not_ease():
    state = SrsState(interval_days=30, ease=2.5, lapses=1)
    result = apply_answer(state, correct=True, reviewed_at=FIXED_TS)
    assert result.interval_days == 1  # lapse reset, not ease penalty
    assert result.ease == 2.5
```

### Pattern 3: Request-scoped context as the only observability groundwork this milestone

**What:** Add a `request_id` bound via `contextvars` in a small middleware, and switch `logging` calls to include it (even with plain stdlib logging + a custom filter — no `structlog`, no exporter, no vendor SDK required yet). This is the *only* piece of "observability" work done this milestone; metrics and tracing remain explicitly out of scope, but this single seam is what makes adding them later a drop-in rather than a refactor.
**When to use:** Add once, early in the milestone (it's infrastructure, not a feature — no spec needed for the seam itself, though the *decision* to add it belongs in `docs/architecture-decisions.md`).
**Trade-offs:** ~30 lines of code, zero new dependencies, negligible runtime cost. Skipping it now and bolting on request correlation later after logs already exist without it is the expensive path — this is the one place "future-proofing" is worth doing today because retrofitting request identity into historical log lines is impossible.

**Example:**
```python
# backend/app/middleware/request_context.py
import contextvars, uuid, logging

request_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("request_id", default="-")

class RequestIdFilter(logging.Filter):
    def filter(self, record):
        record.request_id = request_id_var.get()
        return True

async def request_context_middleware(request, call_next):
    request_id_var.set(str(uuid.uuid4()))
    return await call_next(request)
```
This is deliberately framework-minimal: no OpenTelemetry SDK, no Prometheus client, no log shipper. Those are the actual future-phase work; this middleware is just the seam they'll attach to (trace context propagation and structured-log correlation both need a request-scoped identifier to exist *before* they're added).

## Data Flow

### Request Flow (unchanged shape, one new cross-cutting hop)

```
Flutter ApiClient
    ↓ HTTP + Bearer JWT
[RequestIdMiddleware] → binds request_id to ContextVar
    ↓
[Router] (Pydantic validate, Depends(get_current_app_user))
    ↓
[Service] (orchestrates motor + repository)
    ↓                                    ↓
[Motor] (pure calc)              [Repository] (SQLAlchemy → Supabase Postgres via pooler:6543)
    ↓                                    ↓
[Service] assembles response
    ↓
[Router] → Pydantic schema → JSON
    ↓
Flutter (deserialize into models/)
```

### Schema Evolution Flow (new — replaces `create_all()`)

```
Change entities.py / orm_models.py
    ↓
alembic revision --autogenerate -m "..."
    ↓
Review generated migration by hand (autogenerate misses renames, data migrations)
    ↓
alembic upgrade head   (local dev + CI + prod deploy — same command everywhere)
```

### Key Data Flows

1. **Answer-a-question (existing, unaffected by this milestone):** Flutter → `POST /answer` → `answer_service` → `motor/srs.apply_answer` (pure) → `repository/srs_state` (writes to whatever `DATABASE_URL` points at — SQLite today, Postgres after migration, no code change beyond the connection string and driver).
2. **Request correlation (new):** every inbound request gets a `request_id` at the middleware boundary; every log statement inside routers/services/repository picks it up via the logging filter with zero per-call plumbing. This is the seam future metrics/tracing will reuse (e.g., an OpenTelemetry span can later be started in the same middleware and the `request_id` reused as (or paired with) the `trace_id`).
3. **Schema change (new):** entity/ORM model edits flow through Alembic instead of being auto-applied on boot — this is what unblocks safe production migrations against a real Postgres (SQLite's `create_all()`-on-boot pattern is additive-only and cannot express column drops/renames/constraints, which Postgres in production will eventually need).

## Scaling Considerations

This is a solo-dev side project with no user-growth pressure this milestone — scaling is about *sustainability of the process*, not request throughput.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Solo dev, current feature set | Spec only non-trivial features; TDD only the motor; one middleware for request_id. This is the ceiling of process investment justified right now. |
| Content grows to 50-80 Q/cert × 3 providers | No architecture change needed — content is data (YAML), not code; repository layer already provider-agnostic. |
| Future: multiple contributors | Specs become more valuable (shared understanding without live pairing) — same lightweight format scales fine, no tooling change needed. |
| Future: observability phase | Metrics (Prometheus client + `/metrics` endpoint) and tracing (OpenTelemetry SQLAlchemy + FastAPI auto-instrumentation) both slot into the existing middleware/logging seam without touching motor/service/repository code — confirms this milestone's groundwork is sufficient. |

### Scaling Priorities

1. **First real risk: schema drift under `create_all()` against production Postgres.** SQLite's `create_all()`-on-boot never had to handle destructive changes; Postgres in production will. Alembic must land *before* or *together with* the Postgres migration, not after.
2. **Second risk: connection pool exhaustion via Supabase's pooler.** Supabase's PgBouncer (port 6543, transaction mode) does its own connection multiplexing; if SQLAlchemy is *also* configured with a large `pool_size`, you get double-pooling. Fix: connect through the transaction-mode pooler and keep SQLAlchemy's own pool modest (or `NullPool` if using an async driver like `asyncpg` through pgbouncer), and disable asyncpg's prepared-statement caching (`statement_cache_size=0`) to avoid the well-documented pgbouncer/asyncpg prepared-statement conflict.

## Anti-Patterns

### Anti-Pattern 1: Full upfront spec for every change ("spec-as-source" / spec-driven code generation)

**What people do:** Adopt heavyweight SDD tooling (spec-kit style pipelines) that treat the spec as the sole source of truth and generate code/tests from it, with re-validation loops on every change.
**Why it's wrong:** For a solo dev without an AI-codegen pipeline already in place, this is pure process overhead — the spec becomes a second codebase to keep in sync, and the "generation" step doesn't exist, so you're hand-writing both the spec and the code with no leverage gained.
**Do this instead:** Spec-anchored, not spec-as-source (Pattern 1 above) — write specs as a *thinking tool and durable memory*, checked into `docs/specs/`, referenced by tests, but never treated as an executable artifact.

### Anti-Pattern 2: TDD-everything, including routers and Pydantic schemas

**What people do:** Force red-green-refactor on every layer, including code whose correctness is really "did I wire FastAPI/SQLAlchemy correctly," not "is my business logic right."
**Why it's wrong:** These tests mostly restate framework guarantees, are slow (DB fixtures) and brittle (schema churn breaks tests unrelated to logic changes), and burn the exact time budget a solo dev doesn't have — this is the single most common reason solo devs abandon TDD entirely.
**Do this instead:** Concentrate strict TDD on `motor/` (Pattern 2); use "test-after, lock it in" for `repository/`/`routers/` integration tests.

### Anti-Pattern 3: Keeping `Base.metadata.create_all()` as the schema-management strategy after moving to Postgres

**What people do:** Carry over the SQLite-era "just recreate tables idempotently on boot" pattern into production Postgres because it "still works" during migration.
**Why it's wrong:** It's additive-only (can't drop columns, rename tables, add NOT NULL constraints to existing data, or run data migrations), and multiple app instances booting concurrently against the same Postgres can race on DDL. It also gives you zero migration history/audit trail.
**Do this instead:** Introduce Alembic in the same milestone as the Postgres migration, not as a later cleanup — retrofitting Alembic onto a schema that's already evolved informally means hand-writing an initial "baseline" migration and reconciling drift, which is strictly more work than doing it now.

### Anti-Pattern 4: Adding logging/metrics libraries "just in case" before the observability phase

**What people do:** Pull in `structlog`, a Prometheus client, and OpenTelemetry SDKs now, wire them up minimally, and leave them mostly unused until the observability phase.
**Why it's wrong:** Contradicts the milestone's explicit non-goal (no observability implementation this milestone) and adds dependency surface / config surface that can rot before it's used (SDK version drift, unused exporters misconfigured).
**Do this instead:** Add only the request-context seam (Pattern 3) — a dependency-free `contextvars` + stdlib logging filter. It costs nothing to maintain and is the one piece of groundwork that's genuinely expensive to retrofit later (because request identity has to exist *before* the log lines are written to be correlate-able).

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Supabase Postgres | SQLAlchemy `Engine` via `DATABASE_URL`, connect through the **pooler on port 6543 in transaction mode**, not the direct connection (port 5432) | Direct connection has a low connection ceiling and is meant for migrations/admin, not app traffic; keep `pool_pre_ping=True`, `pool_recycle` under Supabase's idle-connection timeout |
| Supabase Auth (existing) | Unchanged — JWKS-based JWT verification in `auth.py` | Not affected by the DB migration; Auth and Postgres are separate Supabase products even though co-hosted |
| Alembic ↔ Supabase Postgres | Run migrations via the **direct connection** (port 5432), not the transaction-mode pooler | Pooler in transaction mode does not support the session-level features (advisory locks, prepared statements) Alembic/DDL sometimes relies on; this is the documented Supabase guidance |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `docs/specs/` ↔ `tests/unit/` | Human-mediated (spec's Acceptance Criteria become test names/assertions) | No tooling coupling — spec is not parsed by anything; deliberately just documentation with teeth |
| `middleware/request_context.py` ↔ everything downstream | `contextvars.ContextVar`, read implicitly by the logging filter | No parameter threading required through services/repository — this is precisely why it's cheap to add now and expand later (metrics/tracing read the same ContextVar) |
| `repository/db.py` ↔ `alembic/env.py` | Alembic imports the same `Base`/`orm_models` metadata the app uses, so schema drift between "what the app expects" and "what migrations produced" is structurally prevented | Single source of truth for schema stays in `orm_models.py` |

## Sources

- [FastAPI Observability: Correlation IDs & ContextVars (2026), dev.to](https://dev.to/kaushikcoderpy/fastapi-observability-correlation-ids-contextvars-2026-4hm4) — MEDIUM confidence (community post, but pattern matches official Starlette/contextvars docs)
- [Operations-Friendly Observability: A FastAPI Implementation Guide](https://blog.greeden.me/en/2025/10/07/operations-friendly-observability-a-fastapi-implementation-guide-for-logs-metrics-and-traces-request-id-json-logs-prometheus-opentelemetry-and-dashboard-design/) — MEDIUM confidence
- [Supabase Docs: Connect to your database](https://supabase.com/docs/guides/database/connecting-to-postgres) — HIGH confidence (official docs; pooler port/mode guidance)
- [Supabase Docs: Using SQLAlchemy with Supabase](https://supabase.com/docs/guides/troubleshooting/using-sqlalchemy-with-supabase-FUqebT) — HIGH confidence (official docs)
- [SQLAlchemy discussion #8751: pgbouncer best practices](https://github.com/sqlalchemy/sqlalchemy/discussions/8751) — MEDIUM confidence (maintainer-adjacent discussion)
- [The asyncpg + PgBouncer Prepared Statement Trap](https://goldlapel.com/grounds/connection-pooling/asyncpg-pgbouncer-prepared-statement-trap) — MEDIUM confidence (well-documented recurring community issue, corroborated across multiple sources)
- General SDD/TDD-for-solo-devs synthesis (spec-anchored vs. spec-as-source rigor levels; TDD scope discipline) — MEDIUM confidence, cross-checked across multiple 2026 sources on spec-driven development methodology

---
*Architecture research for: CertFly — SDD/TDD process + SQLite→Supabase Postgres migration, observability-ready*
*Researched: 2026-08-11*
