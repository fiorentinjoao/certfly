# Stack Research

**Domain:** SQLite → Supabase Postgres migration + FastAPI authorization hardening (subsequent milestone, not greenfield)
**Researched:** 2026-08-11
**Confidence:** HIGH (migration tooling, connection pooling) / HIGH (authorization patterns — well-established FastAPI idiom)

This is not a "pick a framework" research doc — CertFly's stack is locked (FastAPI + SQLAlchemy 2.0 + psycopg3, sync engine, `create_engine`/`sessionmaker`, no async). Everything below is scoped to *how to execute this milestone's three changes* on top of that existing stack, not alternatives to it.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Alembic | >=1.16,<2.0 (current: 1.18.5/1.19.x) | Schema migration tool for SQLAlchemy | Official SQLAlchemy migration tool, same author/org, integrates directly with the existing `Base`/`DeclarativeBase` metadata already defined in `backend/app/repository/db.py`. Zero new ORM concepts to learn. Autogenerate diffs the current `Base.metadata.create_all()` startup pattern away — this migration IS the reason to adopt it now, not later. |
| psycopg (v3, sync) | `psycopg[binary]>=3.2` (already pinned) | Postgres driver | Already in `pyproject.toml`. Do NOT switch to `asyncpg` or `psycopg2` — the app is fully sync (`create_engine`, sync `Session`, sync FastAPI route handlers via `Depends(get_db)`). Introducing async now is an unrelated, large-blast-radius change and out of scope for this milestone. |
| Supabase direct connection (port 5432) | n/a (connection string) | Production DB connectivity | For a single long-running FastAPI process (not serverless/edge), Supabase's own docs recommend the **direct connection**, not the transaction-mode pooler. This app is a persistent backend (uvicorn process), so it should hold its own connection pool via SQLAlchemy's built-in `QueuePool`, not route every query through Supavisor. Requires IPv6 egress or the IPv4 add-on; if the deploy target is IPv4-only with no add-on, fall back to **Supavisor session mode** (port 5432 on `*.pooler.supabase.com`) — never transaction mode (6543) for this workload. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `alembic` | pin in `pyproject.toml` alongside `sqlalchemy>=2.0` | Migration CLI + versioned migration scripts | Add as a core (not dev-only) dependency — migrations must run in any environment that provisions the DB, including CI/prod deploy. |
| `python-dotenv` | already present (`>=1.0`) | Loads `DATABASE_URL` for local `alembic upgrade head` runs | No change needed — `env.py` should reuse the same `load_dotenv()` + `os.environ["DATABASE_URL"]` pattern already in `db.py`, not duplicate config logic. |
| `testcontainers[postgres]` | `>=4.0` (dev extra) | Spin up a real ephemeral Postgres for integration tests | CONCERNS.md flags SQLite-vs-Postgres behavioral divergence as untested (e.g., `ON CONFLICT`, JSON types, constraint enforcement differ). Add a `postgres`-backed test tier alongside the existing SQLite in-memory tests rather than replacing them outright — SQLite tests stay fast for unit-level logic, testcontainers tests catch dialect-specific bugs before they hit Supabase. |
| `pytest-asyncio` | NOT needed | — | Explicitly not required — the app has no async routes/sessions. Do not add speculatively. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `alembic init alembic` (or `migrations/`) | Scaffolds the migration environment | Point `alembic/env.py`'s `target_metadata` at `app.repository.db.Base.metadata` and import all ORM model modules so autogenerate sees every table — a common footgun is autogenerate producing an empty diff because models were never imported. |
| Alembic `-x` args / `alembic.ini` `sqlalchemy.url` override | Environment-specific DB target | Do not hardcode `DATABASE_URL` in `alembic.ini`; read it from env in `env.py` exactly like `db.py` does, so `alembic upgrade head` targets SQLite locally / Postgres in CI-prod without editing files. |
| Baseline migration via `alembic stamp head` (after first autogenerate) | Reconciles existing dev DBs that already have tables from `create_all()` | Needed once, during the cutover commit, so existing local SQLite/dev Postgres DBs aren't asked to re-create tables that already exist. |

## Installation

```bash
# Core (add to backend/pyproject.toml dependencies, not dev extras)
uv pip install "alembic>=1.16,<2.0"

# Dev-only (for Postgres-parity integration tests)
uv pip install -e ".[dev]"  # after adding testcontainers[postgres]>=4.0 to the dev extra
```

```bash
# One-time scaffold
cd backend
uv run alembic init alembic

# After wiring env.py to Base.metadata + importing all ORM models:
uv run alembic revision --autogenerate -m "baseline schema"
uv run alembic upgrade head
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| Alembic | SQLModel's migration wrapper / `sqlacodegen` | Only if the ORM layer were being rewritten in SQLModel — it isn't; CertFly uses plain SQLAlchemy 2.0 `DeclarativeBase`. No reason to add SQLModel just for migrations. |
| Alembic | Supabase CLI migrations (`supabase migration new`, SQL-first) | Viable if the team wanted Supabase to own schema (e.g., using Supabase Studio, RLS-heavy design, or the JS/Deno ecosystem). CertFly's schema is owned by SQLAlchemy models in Python — Alembic keeps schema-as-code colocated with the ORM that defines it, avoiding two sources of truth. |
| Direct connection (5432) | Supavisor transaction pooler (6543) | Only relevant if the backend moves to serverless/edge functions (e.g., Vercel Edge, AWS Lambda) with many short-lived cold-start connections. CertFly runs a single persistent uvicorn process — pooler transaction mode would add prepared-statement complexity (`prepare_threshold=None` workarounds) for no benefit at this scale. |
| SQLAlchemy `QueuePool` (default) | `NullPool` + Supavisor transaction mode | Only needed if deploying many short-lived FastAPI worker instances (e.g., one process per request, common in some serverless FastAPI deployments). Not applicable to a single long-running server. |
| `Depends`-based ownership-check dependency (service-layer) | FastAPI-native RBAC libraries (`fastapi-permissions`, Casbin, Oso) | Only worth the added dependency if the app grows real roles/permissions (admin vs. user, teams, shared resources). CertFly's ownership model is simple ("does `session.user_id` == the authenticated user's id") — a hand-written dependency is less code and less to learn than a policy-engine library for a single-owner-per-resource check. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|--------------|
| `Base.metadata.create_all()` as the ongoing schema-sync mechanism | Works for "create if missing" but has no concept of altering/dropping columns, renaming, or tracking what's already applied — it's why the 3 security-gap fixes and Postgres migration need real migrations now. Already flagged in `CONCERNS.md` as tech debt. | Alembic versioned migrations; keep `create_all()` only as a test-fixture convenience for the SQLite unit-test tier if desired, never for Postgres/prod. |
| Supavisor **transaction mode** (port 6543) for this backend | Breaks psycopg3 prepared statements unless `prepare_threshold=None` is set and PgBouncer >=1.22/libpq from PG17 — adds a footgun for zero benefit on a long-running single process. Confirmed by Supabase's own troubleshooting doc and multiple 2026 postmortems. | Direct connection (5432) or Supavisor session mode (5432) — see Core Technologies table. |
| Client-side-only enforcement of the topic-unlock gate (current state per CONCERNS.md) | Trivially bypassed by calling `POST /topic/{id}/lesson` directly — this is exactly the security gap this milestone must close. | Server-side check inside the service layer (`lesson_service.start_lesson` or an owning dependency) that re-validates unlock state from the DB before returning lesson content, mirroring the pattern already proven in the `unlock_topic` fix (`session_service.py` + `catalog.py::get_next_topic_id` + its regression test). |
| Ad-hoc `if session.user_id != current_user.id: raise HTTPException(403)` scattered per-endpoint | Works but doesn't scale past 2-3 endpoints and is easy to forget on new routes — exactly how the missing ownership check on lesson-session completion happened. | A small reusable FastAPI dependency (e.g., `get_owned_lesson_session(session_id, user=Depends(get_current_user), db=Depends(get_db))`) that fetches the resource and raises `404` (not `403`, to avoid leaking existence of other users' resources) if `user_id` doesn't match, injected via `Depends()` into every endpoint that touches a user-owned resource. |
| Leaving `SUPABASE_JWT_SECRET`/HS256 fallback reachable by any non-empty env value | Root cause of pitfall #3: dev bypass activates whenever the var happens to be set, with no environment gate. | Explicit environment check (e.g., only allow HS256 path when `ENVIRONMENT=development`/`APP_ENV != production`, not merely "secret is set") — see PITFALLS.md for detail. |
| Testing exclusively against SQLite in-memory going forward | SQLite and Postgres diverge on constraint enforcement, `ON CONFLICT`, type coercion, and case sensitivity — exactly the gap CONCERNS.md calls "Scaling Limits: SQLite vs. Postgres behavioral divergence not tested." Silent bugs ship straight to the new Postgres backend. | Keep fast SQLite unit tests for logic-only tests; add a `testcontainers`-backed Postgres integration tier (function- or module-scoped fixture) for anything touching real constraints/migrations. |

## Stack Patterns by Variant

**If deploying to a platform with IPv6 egress (most VPS/container hosts, Fly.io, Railway, Render):**
- Use the Supabase **direct connection** (port 5432, `db.[project-ref].supabase.co`)
- Because it gives the app its own dedicated connection, avoids pooler-mode caveats entirely, and is what Supabase recommends for "migrations, `pg_dump`, long-lived backend."

**If deploying to an IPv4-only platform without the Supabase IPv4 add-on:**
- Use Supavisor **session mode** (port 5432, `*.pooler.supabase.com`), paired with SQLAlchemy's own `QueuePool` sized conservatively (e.g., `pool_size=5, max_overflow=5` for a solo-project scale)
- Because session mode supports prepared statements (unlike transaction mode) and behaves like a normal Postgres connection from the app's perspective — no driver-level workarounds needed.

**If/when the app is later split into multiple short-lived worker processes or moves to serverless:**
- Revisit and switch to Supavisor transaction mode (6543) + `NullPool` + `prepare_threshold=None`
- Because that's the scenario the transaction pooler is actually designed for; premature adoption now adds complexity with no payoff.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|------------------|-------|
| `alembic>=1.16` | `sqlalchemy>=2.0` (already pinned) | Alembic 1.16+ is built against SQLAlchemy 2.0's typed `DeclarativeBase`/`Mapped[]` style; no version conflict with the existing `pyproject.toml` pin. |
| `psycopg[binary]>=3.2` | Supabase Postgres (managed, currently Postgres 15/16 series) | Already the pinned driver; psycopg3 is the modern, actively maintained driver (psycopg2 is legacy/maintenance-mode) — no change needed, just confirming it's the right choice to keep. |
| `psycopg[binary]>=3.2` | Supavisor transaction mode | Requires PgBouncer >=1.22 and `prepare_threshold=None` (or a very high threshold) to avoid prepared-statement errors — only relevant if session/direct mode is later abandoned; irrelevant under the recommended direct/session-mode setup. |
| `testcontainers[postgres]` | Docker/Podman available in dev + CI environment | Requires a container runtime; if CI runners don't have Docker available this tier can't run there — verify the eventual CI choice supports it before committing to this pattern in ROADMAP phase planning. |

## Sources

- Supabase official docs — "Connect to your database" (https://supabase.com/docs/guides/database/connecting-to-postgres) — HIGH confidence, verified direct/session/transaction pooler guidance and port numbers
- Supabase official docs — "Using SQLAlchemy with Supabase" troubleshooting guide (https://supabase.com/docs/guides/troubleshooting/using-sqlalchemy-with-supabase-FUqebT) — HIGH confidence, verified NullPool/pool_size/max_overflow patterns
- Supabase official docs — "Supavisor FAQ" (https://supabase.com/docs/guides/troubleshooting/supavisor-faq-YyP5tI) — HIGH confidence
- Alembic official docs / GitHub releases (https://alembic.sqlalchemy.org/en/latest/front.html, https://github.com/sqlalchemy/alembic/releases) — HIGH confidence, current version confirmed as 1.18.x/1.19.x as of Aug 2026
- psycopg3 official docs — "Prepared statements" (https://www.psycopg.org/psycopg3/docs/advanced/prepare.html) — HIGH confidence
- pgbouncer GitHub discussion #995 on prepared statements — MEDIUM confidence (community, cross-checked against psycopg official docs)
- FastAPI official docs — "Dependencies - Depends() and Security()" (https://fastapi.tiangolo.com/reference/dependencies/) — HIGH confidence, official framework docs for the ownership-dependency pattern
- Community sources (Medium/dev.to) on FastAPI RBAC/ownership patterns and Alembic production practices — MEDIUM confidence, used only to corroborate patterns already consistent with official docs and the codebase's own proven `unlock_topic` fix pattern, not as sole basis for any recommendation

---
*Stack research for: CertFly Postgres migration + authorization hardening milestone*
*Researched: 2026-08-11*
