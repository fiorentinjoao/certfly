# Codebase Structure

**Analysis Date:** 2026-08-11

## Directory Layout

```
certfly/
├── backend/                    # FastAPI service (Python 3.12, uv/pyproject)
│   ├── app/
│   │   ├── main.py             # FastAPI app entry point, router registration
│   │   ├── auth.py             # Supabase JWT verification
│   │   ├── models/
│   │   │   └── entities.py     # Canonical domain dataclasses
│   │   ├── motor/               # Pure business rules (no I/O)
│   │   │   ├── srs.py          # Spaced repetition (SM-2 adapted)
│   │   │   ├── mastery.py      # Topic mastery % calculation
│   │   │   └── xp.py           # XP/streak scoring rules
│   │   ├── repository/          # SQLAlchemy I/O, one module per aggregate
│   │   │   ├── db.py           # Engine/session config, Base, get_db dependency
│   │   │   ├── orm_models.py   # SQLAlchemy ORM schema
│   │   │   ├── mappers.py      # ORM ↔ entity translation
│   │   │   ├── catalog.py      # Read-only content queries
│   │   │   ├── srs_state.py    # UserQuestionState persistence
│   │   │   ├── attempts.py     # Attempt log writes
│   │   │   ├── users.py        # AppUser get-or-create, XP/streak updates
│   │   │   └── lesson_sessions.py
│   │   ├── services/            # Use-case orchestration (motor + repository)
│   │   │   ├── lesson_service.py
│   │   │   ├── answer_service.py
│   │   │   ├── session_service.py
│   │   │   ├── progress_service.py
│   │   │   ├── certifications_service.py
│   │   │   └── topic_mastery.py
│   │   └── routers/             # FastAPI endpoints + Pydantic schemas
│   │       ├── deps.py         # Composed FastAPI dependencies (auth + repo)
│   │       ├── schemas.py      # Pydantic request/response models
│   │       ├── me.py           # GET /me
│   │       ├── progress.py     # GET /certification/{id}/progress
│   │       ├── certifications.py # GET /certifications
│   │       ├── lesson.py       # POST /topic/{id}/lesson
│   │       ├── answer.py       # POST /question/{id}/answer
│   │       └── lesson_session.py # POST /lesson-session/{id}/complete
│   ├── tests/
│   │   ├── unit/                # Motor-only tests (no DB) — test_srs.py, test_xp.py, test_mastery.py, test_entities.py
│   │   └── integration/         # DB + API tests — test_repository.py, test_services.py, test_api.py
│   ├── pyproject.toml           # Dependencies, pytest config (uv/setuptools)
│   ├── .env.example              # DATABASE_URL / SUPABASE_URL / SUPABASE_JWT_SECRET template
│   └── certfly.db                # Local SQLite dev DB (gitignored data, present on disk)
├── frontend/                    # Flutter app (Dart)
│   └── lib/
│       ├── main.dart             # App entry point, bootstrap/auth-gate routing
│       ├── theme.dart            # AppTheme (dark theme)
│       ├── config/
│       │   └── app_config.dart   # Env-driven config (--dart-define-from-file)
│       ├── auth/
│       │   └── auth_gateway.dart # AuthGateway abstraction (Supabase vs. dev token)
│       ├── api/
│       │   ├── api_client.dart   # Typed HTTP client for all backend endpoints
│       │   └── api_exception.dart
│       ├── models/                # JSON (de)serialization matching backend schemas
│       │   ├── me.dart, certification.dart, lesson.dart,
│       │   │   lesson_summary.dart, progress.dart, answer.dart
│       ├── screens/                # One file per screen/flow
│       │   ├── welcome_screen.dart, login_screen.dart,
│       │   │   forgot_password_screen.dart, new_password_screen.dart,
│       │   │   main_shell.dart, home_screen.dart, certifications_screen.dart,
│       │   │   lesson_screen.dart, lesson_summary_screen.dart,
│       │   │   profile_screen.dart, coming_soon_tab.dart,
│       │   │   missing_config_screen.dart
│       └── widgets/                # Reusable UI components
│           ├── bottom_nav_bar.dart, streak_hero.dart, domain_path.dart,
│           │   animated_progress_bar.dart, count_up_text.dart,
│           │   fade_slide_in.dart, app_page_route.dart
├── content/                      # Provider-agnostic question banks (data, not code)
│   ├── gcp-pde.yaml               # Google Cloud Professional Data Engineer
│   ├── aws-dea-c01.yaml           # AWS Data Engineer – Associate
│   └── azure-dp700.yaml           # Azure DP-700
├── scripts/
│   └── seed_dev.py                 # Loads content/*.yaml into DB, mints dev JWT + dev.json
├── docs/                            # Product/architecture docs (market research, spec, ADRs, system design)
└── .planning/                      # GSD planning artifacts (this analysis lives here)
```

## Directory Purposes

**`backend/app/motor/`:**
- Purpose: Pure, side-effect-free business rules — the "engine" of the app
- Contains: SRS scheduling (`srs.py`), mastery % (`mastery.py`), XP/streak rules (`xp.py`)
- Key files: `backend/app/motor/srs.py` (SM-2-adapted spaced repetition, see `docs/core-loop-srs.md`)

**`backend/app/repository/`:**
- Purpose: All database access — SQLAlchemy models, session management, queries
- Contains: One module per aggregate root (catalog, attempts, srs_state, users, lesson_sessions), plus shared `db.py`/`orm_models.py`/`mappers.py`
- Key files: `backend/app/repository/db.py` (connection/session setup), `backend/app/repository/orm_models.py` (schema)

**`backend/app/services/`:**
- Purpose: Orchestrates a single use case per file — reads repository state, calls motor, writes repository state
- Contains: Plain functions, one file roughly per API endpoint
- Key files: `backend/app/services/lesson_service.py`, `backend/app/services/answer_service.py`

**`backend/app/routers/`:**
- Purpose: HTTP layer — FastAPI route definitions and Pydantic wire schemas
- Contains: One `APIRouter` per resource, `deps.py` for composed auth+DB dependencies, `schemas.py` for all request/response models
- Key files: `backend/app/routers/deps.py`, `backend/app/routers/schemas.py`

**`backend/tests/unit/`:**
- Purpose: Fast tests of pure motor logic, no database
- Contains: `test_srs.py`, `test_xp.py`, `test_mastery.py`, `test_entities.py`

**`backend/tests/integration/`:**
- Purpose: Tests against a real (SQLite) DB and the FastAPI app via `TestClient`
- Contains: `test_repository.py` (repository layer), `test_services.py` (service orchestration), `test_api.py` (end-to-end HTTP), `conftest.py` (fixtures)

**`frontend/lib/screens/`:**
- Purpose: One file per app screen/flow — no shared "pages" abstraction beyond this
- Contains: `StatefulWidget`/`StatelessWidget` classes wired to `ApiClient`

**`frontend/lib/widgets/`:**
- Purpose: Reusable, composable UI pieces shared across screens (nav bar, progress bar, animations)

**`frontend/lib/api/` and `frontend/lib/models/`:**
- Purpose: Backend contract layer — `ApiClient` (HTTP calls) + one model file per JSON shape returned by the backend

**`content/`:**
- Purpose: Data-only YAML files defining certification question banks (domains → topics → questions → choices), loaded via `scripts/seed_dev.py`. Not application code.

**`scripts/`:**
- Purpose: Dev-only operational scripts (currently just `seed_dev.py`, which seeds local SQLite from `content/*.yaml` and produces a dev JWT + `dev.json` for the Flutter `--dart-define-from-file` flow)

**`docs/`:**
- Purpose: Product and architecture reference docs (market research, product spec, architecture decisions, core-loop/SRS design, requirements, system design, content plan) — read these before making architecture-affecting changes

## Key File Locations

**Entry Points:**
- `backend/app/main.py`: FastAPI app construction, router registration, `/health`
- `frontend/lib/main.dart`: Flutter app bootstrap, auth-state routing

**Configuration:**
- `backend/.env.example`: Template for `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_JWT_SECRET`
- `backend/pyproject.toml`: Python deps + pytest config
- `frontend/lib/config/app_config.dart`: Env-driven config (`apiBaseUrl`, `supabaseUrl`, `supabaseAnonKey`, `devToken`, `certificationId`)

**Core Logic:**
- `backend/app/motor/srs.py`: Spaced-repetition scheduling algorithm
- `backend/app/services/*.py`: Use-case orchestration, one file per endpoint
- `backend/app/repository/catalog.py`: Content navigation (trail/unlock logic)

**Testing:**
- `backend/tests/unit/`: Motor-only, no DB
- `backend/tests/integration/`: DB + API via `TestClient`
- Run: `cd backend && .venv/bin/python -m pytest`
- No frontend test suite observed beyond the default `frontend/test/` scaffold — verify before assuming coverage

## Naming Conventions

**Backend files:**
- `snake_case.py`, one concept/resource per file (`lesson_service.py`, `srs_state.py`)
- Router files named after the resource/URL segment (`lesson.py` → `/topic/{id}/lesson`, `answer.py` → `/question/{id}/answer`)

**Backend functions:**
- `snake_case`, verb-first for actions (`start_lesson`, `answer_question`, `get_or_create_user`)
- Repository getters prefixed `get_`, writes use verbs like `save`, `record`, `add_xp`, `create`

**Backend types:**
- `PascalCase` dataclasses for entities/motor state (`AppUser`, `SRSState`, `LessonQuestion`)
- Pydantic response models suffixed `Response` (`MeResponse`, `LessonResponse`, `CertificationOverviewResponse`)

**Frontend files:**
- `snake_case.dart` (Dart convention), one screen per file suffixed `_screen.dart`, one widget per file matching its class name in `snake_case`

**Frontend types:**
- `PascalCase` classes matching backend concepts (`Me`, `Lesson`, `LessonSummary`, `CertificationOverview`, `DomainProgress`)

**Content YAML:**
- `{provider}-{cert-slug}.yaml` (e.g., `gcp-pde.yaml`, `aws-dea-c01.yaml`, `azure-dp700.yaml`)

## Where to Add New Code

**New backend endpoint/use case:**
1. Add/extend entity in `backend/app/models/entities.py` if new domain shape is needed
2. Add repository function(s) in the relevant `backend/app/repository/*.py` (or new file per aggregate)
3. Add pure rule logic to `backend/app/motor/*.py` only if it's genuinely I/O-free business logic; otherwise put orchestration directly in a new `backend/app/services/*.py` function
4. Add Pydantic request/response models to `backend/app/routers/schemas.py`
5. Add router in `backend/app/routers/*.py`, register it in `backend/app/main.py`
6. Add unit test (motor) in `backend/tests/unit/` and/or integration test in `backend/tests/integration/`

**New Flutter screen:**
- Screen: `frontend/lib/screens/{name}_screen.dart`
- Model (if new JSON shape): `frontend/lib/models/{name}.dart`
- API method: add to `frontend/lib/api/api_client.dart`
- Wire into navigation via `frontend/lib/screens/main_shell.dart` or the relevant parent screen

**New certification content:**
- Add `content/{provider}-{cert-slug}.yaml` following the existing 3 files' structure
- Reseed via `scripts/seed_dev.py`

**Shared UI component:**
- `frontend/lib/widgets/{name}.dart`

## Special Directories

**`backend/certfly.db`:**
- Purpose: Local SQLite database file for dev/test
- Generated: Yes (created by `Base.metadata.create_all` on app boot)
- Committed: Present in working tree at analysis time — verify `.gitignore` before assuming it's tracked; treat as disposable/regeneratable via `scripts/seed_dev.py`

**`backend/.venv/`, `backend/.pytest_cache/`, `backend/certfly_backend.egg-info/`:**
- Purpose: Python virtualenv, pytest cache, editable-install metadata
- Generated: Yes
- Committed: No (standard Python tooling artifacts)

**`frontend/build/`, `frontend/.dart_tool/`:**
- Purpose: Flutter build output and tool cache
- Generated: Yes
- Committed: No

**`frontend/android/`, `frontend/ios/`, `frontend/linux/`:**
- Purpose: Platform-specific Flutter scaffolding (native project files)
- Generated: Partially (scaffolded by `flutter create`, then customized)
- Committed: Yes (standard for Flutter multi-platform projects)

**`.planning/`:**
- Purpose: GSD workflow planning artifacts (roadmap, phase plans, this codebase analysis)
- Generated: Yes (by GSD commands)
- Committed: Per GSD conventions

---

*Structure analysis: 2026-08-11*
