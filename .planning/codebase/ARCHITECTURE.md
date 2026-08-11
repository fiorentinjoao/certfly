<!-- refreshed: 2026-08-11 -->
# Architecture

**Analysis Date:** 2026-08-11

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Frontend (client)                 │
│  screens/ (UI) → api/api_client.dart (HTTP) + auth_gateway.dart│
│  `frontend/lib/`                                              │
└──────────────────────┬─────────────────────────────────────┘
                        │ HTTPS + Bearer <Supabase JWT>
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                  FastAPI Backend (app/main.py)                │
├──────────────────┬──────────────────┬───────────────────────┤
│    routers/       │    services/      │      motor/           │
│  HTTP + Pydantic  │  orchestrates     │  pure business rules  │
│  `app/routers/`   │  motor+repository │  (SRS, mastery, XP)   │
│                    │  `app/services/`  │  `app/motor/`         │
└────────┬───────────┴────────┬──────────┴──────────┬───────────┘
         │                    │                     │
         ▼                    ▼                     │
┌─────────────────────────────────────────────────────────────┐
│                repository/ (SQLAlchemy I/O)                   │
│   orm_models.py (schema) · db.py (session) · mappers.py       │
│   + 1 module per aggregate (catalog, attempts, srs_state, ...)│
│   `app/repository/`                                           │
└──────────────────────┬─────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  SQLite (local dev, `backend/certfly.db`) /                   │
│  Postgres via Supabase (production, `DATABASE_URL`)           │
│  Auth: Supabase Auth (JWT, JWKS/ES256, or HS256 dev fallback)  │
└─────────────────────────────────────────────────────────────┘
```

**Content authoring pipeline (separate, offline):**
```text
content/*.yaml (GCP/AWS/Azure question banks)
    → scripts/seed_dev.py → repository ORM → DB
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| FastAPI app | Wires routers, creates tables on boot, health check | `backend/app/main.py` |
| Routers | HTTP endpoints, Pydantic request/response, auth dependency wiring | `backend/app/routers/*.py` |
| Services | Orchestrate motor (pure rules) + repository (I/O) per use case | `backend/app/services/*.py` |
| Motor | Pure business rules: SRS scheduling, mastery %, XP/streak — no I/O | `backend/app/motor/*.py` |
| Repository | SQLAlchemy queries/writes, 1 module per aggregate, ORM↔entity mapping | `backend/app/repository/*.py` |
| Entities | Domain dataclasses — the single source of truth for domain shape | `backend/app/models/entities.py` |
| Auth | Supabase JWT verification (JWKS/ES256, HS256 dev fallback) | `backend/app/auth.py` |
| Flutter screens | UI per feature/flow (login, lesson, progress, profile) | `frontend/lib/screens/*.dart` |
| ApiClient | Typed HTTP client for the 6 backend endpoints | `frontend/lib/api/api_client.dart` |
| AuthGateway | Abstracts token source (Supabase session vs. dev token) | `frontend/lib/auth/auth_gateway.dart` |
| Content YAML | Provider-agnostic question banks per certification | `content/*.yaml` |
| seed_dev.py | Loads content YAML into DB + mints a dev JWT | `scripts/seed_dev.py` |

## Pattern Overview

**Overall:** Layered architecture (routers → services → motor/repository) on the backend, single-repo monolith split into `backend/` (FastAPI) and `frontend/` (Flutter), sharing a REST/JSON contract. No ORM entities leak past `repository/`; no Pydantic models are used outside `routers/`.

**Key Characteristics:**
- **Pure-core, imperative-shell**: `app/motor/*` is intentionally side-effect-free (no DB, no clock, no I/O) so it can be unit-tested without mocking. Services provide the "shell" that reads state, calls the motor, and persists results.
- **Three independent data shapes for the same concepts**: `models/entities.py` (domain dataclasses), `repository/orm_models.py` (SQLAlchemy ORM), `routers/schemas.py` (Pydantic wire format). Each layer maps into entities; entities are canonical.
- **Provider-agnostic content modeling**: `Provider → Certification → Domain → Topic → Question → Choice` hierarchy has no cloud-specific fields, enabling GCP/AWS/Azure content to share one schema (`docs/architecture-decisions.md`).
- **Dependency injection via FastAPI `Depends`**: DB sessions and authenticated users are injected per-request, never module-level globals.

## Layers

**Routers (`backend/app/routers/`):**
- Purpose: HTTP surface — parse requests, call services, serialize Pydantic responses
- Location: `backend/app/routers/*.py` (one file per resource: `me.py`, `progress.py`, `certifications.py`, `lesson.py`, `answer.py`, `lesson_session.py`)
- Contains: FastAPI `APIRouter` instances, endpoint functions with `Depends(get_current_app_user)` and `Depends(get_db)`
- Depends on: `services/`, `routers/schemas.py`, `routers/deps.py`
- Used by: `app/main.py` (registers routers)

**Services (`backend/app/services/`):**
- Purpose: Orchestrate one use case each — read repository state, call motor, write repository state
- Location: `backend/app/services/*.py`
- Contains: Plain functions (not classes) taking a `Session` + args, returning dataclasses
- Depends on: `motor/`, `repository/`, `models/entities.py`
- Used by: `routers/`

**Motor (`backend/app/motor/`):**
- Purpose: Pure business rules — SRS scheduling (`srs.py`), topic mastery % (`mastery.py`), XP/streak (`xp.py`)
- Location: `backend/app/motor/*.py`
- Contains: Frozen dataclasses + pure functions, zero I/O, zero clock access (dates/times passed in as args)
- Depends on: nothing (no imports from repository/routers)
- Used by: `services/`

**Repository (`backend/app/repository/`):**
- Purpose: All SQLAlchemy I/O — one module per aggregate root
- Location: `backend/app/repository/*.py` (`catalog.py`, `attempts.py`, `srs_state.py`, `users.py`, `lesson_sessions.py`, plus `db.py` for session/engine and `orm_models.py` for schema, `mappers.py` for ORM→entity translation)
- Contains: Query functions, `Base.metadata` ORM classes, session dependency (`get_db`)
- Depends on: SQLAlchemy, `models/entities.py` (return type)
- Used by: `services/`

**Models (`backend/app/models/entities.py`):**
- Purpose: Canonical domain shape — frozen dataclasses, no I/O/HTTP deps
- Location: `backend/app/models/entities.py`
- Contains: `Provider`, `Certification`, `Domain`, `Topic`, `Question`, `Choice`, `AppUser`, `UserQuestionState`, `Attempt`, `UserTopicProgress`, `LessonSession`
- Depends on: nothing (stdlib only)
- Used by: `repository/`, `services/`, `routers/` (via schemas mapping)

**Flutter UI (`frontend/lib/screens/`):**
- Purpose: Presentation layer — one screen per flow (welcome, login, home, lesson, progress, profile, password recovery)
- Location: `frontend/lib/screens/*.dart`
- Contains: `StatefulWidget`/`StatelessWidget` classes calling `ApiClient`
- Depends on: `frontend/lib/api/`, `frontend/lib/models/`, `frontend/lib/widgets/`, `frontend/lib/auth/`
- Used by: `frontend/lib/main.dart` (routes to `MainShell`)

**Flutter API layer (`frontend/lib/api/`, `frontend/lib/models/`):**
- Purpose: Typed HTTP client + JSON (de)serialization matching backend Pydantic schemas
- Location: `frontend/lib/api/api_client.dart`, `frontend/lib/api/api_exception.dart`, `frontend/lib/models/*.dart`
- Contains: `ApiClient` class (one method per endpoint), model classes with `fromJson`
- Depends on: `package:http`
- Used by: `screens/`

## Data Flow

### Primary Request Path — answering a lesson question

1. Flutter `LessonScreen` calls `ApiClient.answerQuestion(questionId, choiceId)` → `POST /question/{id}/answer` (`frontend/lib/screens/lesson_screen.dart`, `frontend/lib/api/api_client.dart:74`)
2. FastAPI router `answer.py` authenticates via `Depends(get_current_app_user)` (JWT → `AppUser`, auto-creating the app_user row if missing) (`backend/app/routers/answer.py`, `backend/app/routers/deps.py:13`)
3. `services/answer_service.answer_question` reads current `UserQuestionState` from `repository/srs_state.py`, calls pure `motor/srs.apply_answer` for the new SRS state and `motor/xp.xp_for_answer` for XP, then persists via `repository/srs_state.py`, `repository/attempts.py`, `repository/users.py` (`backend/app/services/answer_service.py:24`)
4. Router serializes the result into `AnswerResultResponse` (Pydantic, `routers/schemas.py`) and returns JSON
5. Flutter `ApiClient` decodes into `AnswerResult` model and the screen updates UI (progress bar, XP toast)

### Lesson Session Lifecycle (RF-08/RF-09 — streak + topic unlock gate)

1. `POST /topic/{id}/lesson` → `services/lesson_service.start_lesson` selects due-for-review questions first, then new questions (up to `LESSON_SIZE = 10`), and creates a `LessonSession` row (`backend/app/services/lesson_service.py:28`)
2. User answers each question via `POST /question/{id}/answer` (per-question flow above)
3. `POST /lesson-session/{id}/complete` → `services/session_service.py` marks the session complete, updates streak (`AppUser.current_streak`/`longest_streak`), and evaluates the topic mastery gate (`motor/mastery.py`) to unlock the next topic via `repository/catalog.get_next_topic_id`
4. Response feeds `LessonSummaryScreen` (XP earned, streak, mastery delta, next-topic unlock)

**State Management:**
- Backend: no server-side session state beyond the DB — every request is stateless except the authenticated user resolved per-request from the JWT
- Frontend: `MainShell` holds the `ApiClient` instance and passes it down; screens are otherwise stateless between navigations (no global state manager — no Provider/Riverpod/Bloc in use)

## Key Abstractions

**Motor (pure functions):**
- Purpose: Deterministic, testable business rules isolated from I/O and clock
- Examples: `backend/app/motor/srs.py` (SM-2-adapted spaced repetition), `backend/app/motor/xp.py`, `backend/app/motor/mastery.py`
- Pattern: Frozen dataclass in/out (`SRSState` in, `SRSState` out); callers own persistence and `due_date` computation (motor never calls `datetime.now()`)

**Entities vs. ORM vs. Schemas (three-model mapping):**
- Purpose: Decouple wire format, persistence format, and domain format so each can change independently
- Examples: `backend/app/models/entities.py` (domain), `backend/app/repository/orm_models.py` (SQLAlchemy), `backend/app/routers/schemas.py` (Pydantic), translated via `backend/app/repository/mappers.py`
- Pattern: repository and routers map INTO entities, never the reverse — entities are the source of truth

**Repository-per-aggregate:**
- Purpose: Keep SQL/session logic out of services; one file per bounded concept
- Examples: `catalog.py` (read-only content), `srs_state.py`, `attempts.py`, `users.py`, `lesson_sessions.py`
- Pattern: Plain functions taking `Session` as first arg, returning entities or `None`

**Provider-agnostic content hierarchy:**
- Purpose: Model GCP/AWS/Azure certifications with one schema
- Examples: `Provider → Certification → Domain → Topic → Question → Choice` in `models/entities.py`; instantiated per cloud in `content/gcp-pde.yaml`, `content/aws-dea-c01.yaml`, `content/azure-dp700.yaml`
- Pattern: No provider-specific fields anywhere in the domain model; providers differ only in data, not schema

## Entry Points

**Backend HTTP server:**
- Location: `backend/app/main.py`
- Triggers: `uvicorn app.main:app --reload`
- Responsibilities: Creates FastAPI app, runs `Base.metadata.create_all` (idempotent dev-only migration), registers 6 routers (`me`, `progress`, `certifications`, `lesson`, `answer`, `lesson_session`), exposes `GET /health`

**Flutter app:**
- Location: `frontend/lib/main.dart`
- Triggers: `flutter run`
- Responsibilities: Initializes Supabase SDK, decides bootstrap path (`MissingConfigScreen` / dev-token shortcut / real `_AuthGate` via Supabase session stream), constructs `ApiClient` with the resolved token, mounts `MainShell`

**Dev seed script:**
- Location: `scripts/seed_dev.py`
- Triggers: run manually (`python scripts/seed_dev.py`) against local SQLite
- Responsibilities: Loads `content/*.yaml` into the DB via repository/ORM, mints a dev JWT + `dev.json` config for `--dart-define-from-file`

## Architectural Constraints

- **Threading:** FastAPI/uvicorn default (async-capable but current routers/services are synchronous functions run in the default threadpool); SQLite connections use `check_same_thread=False` specifically to support this
- **Global state:** `backend/app/auth.py` memoizes a JWKS client with `@lru_cache(maxsize=1)` (module-level singleton, intentional — caches signing keys by `kid`); `backend/app/repository/db.py` has module-level `engine`/`SessionLocal` singletons
- **No migration tool:** `Base.metadata.create_all(bind=engine)` runs on every boot including against production Postgres — additive-only, no destructive schema changes are supported yet (see `backend/app/main.py:14-17` comment)
- **No async DB layer:** SQLAlchemy sessions are synchronous (`sessionmaker`, not `async_sessionmaker`) — do not introduce `async def` repository functions without also switching the engine
- **Frontend has no state management library:** no Provider/Riverpod/Bloc — state lives in `StatefulWidget`s and is passed via constructor args (`ApiClient`, `certificationId`) from `main.dart` down through `MainShell`

## Anti-Patterns

### Leaking ORM or Pydantic models across layers

**What happens:** None observed currently — the codebase consistently keeps `orm_models.py` inside `repository/` and `schemas.py` inside `routers/`, translating through `models/entities.py`.
**Why it's wrong:** Would couple the public API contract to database schema details, making either hard to evolve independently.
**Do this instead:** When adding new fields/endpoints, add them to `entities.py` first, then wire `orm_models.py` and `schemas.py` to map through it — follow `backend/app/repository/mappers.py` as the pattern.

### Putting I/O or clock access inside `app/motor/`

**What happens:** Not present in the current motor modules (`srs.py`, `xp.py`, `mastery.py` are all pure).
**Why it's wrong:** Would break the "testable without mocking" property that lets `backend/tests/unit/` test business rules without a database.
**Do this instead:** Compute `due_date`/timestamps in the calling service (see `backend/app/services/answer_service.py`), pass `now`/`today` as explicit arguments into services from routers (see `backend/app/routers/lesson.py:24`).

## Error Handling

**Strategy:** FastAPI's built-in `HTTPException` for auth/HTTP-level errors; plain `ValueError` for service-level invariant violations (caught implicitly by FastAPI as 500s — no global exception handler registered in `main.py`).

**Patterns:**
- `backend/app/auth.py` raises `HTTPException(401, ...)` for missing/invalid/malformed JWTs
- `backend/app/services/answer_service.py:33` raises bare `ValueError` when a choice doesn't belong to the given question (currently surfaces as unhandled 500 — no explicit 400 mapping)
- Frontend `frontend/lib/api/api_exception.dart` wraps non-2xx HTTP responses into a typed `ApiException(statusCode, body)`

## Cross-Cutting Concerns

**Logging:** No structured logging framework configured; relies on uvicorn's default access/error logs.
**Validation:** Pydantic models in `routers/schemas.py` validate request/response shape at the HTTP boundary; no separate validation library used inside services.
**Authentication:** Every route (except `/health`) depends on `get_current_app_user` (`backend/app/routers/deps.py:13`), which combines JWT verification (`app/auth.py`) with get-or-create app_user lookup (`repository/users.py`) — routes cannot assume the user record already exists.

---

*Architecture analysis: 2026-08-11*
