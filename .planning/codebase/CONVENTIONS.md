# Coding Conventions

**Analysis Date:** 2026-08-11

This is a two-stack codebase: a Python/FastAPI backend (`backend/`) and a
Flutter/Dart frontend (`frontend/`). Conventions differ by stack; each is
documented separately below.

## Naming Patterns

**Backend (Python) files:**
- `snake_case.py` throughout — e.g. `answer_service.py`, `lesson_session.py`, `topic_mastery.py`
- One module per router (`app/routers/answer.py`), one per service (`app/services/answer_service.py`) — router and service names mirror each other minus the `_service` suffix

**Backend functions/variables:**
- `snake_case` — e.g. `get_or_default`, `apply_answer`, `xp_for_answer`
- Private/internal helpers prefixed with `_` — e.g. `_apply_correct_answer`, `_decode`, `_jwks_client`, `_uri`

**Backend types:**
- `PascalCase` for classes/dataclasses — e.g. `AnswerResult`, `SRSState`, `AppUser`
- ORM models suffixed `ORM` — e.g. `QuestionORM`, `TopicORM`, `ProviderORM` (`app/repository/orm_models.py`)
- Pydantic API schemas suffixed `Request`/`Response` — e.g. `AnswerRequest`, `AnswerResponse`, `LessonResponse` (`app/routers/schemas.py`)
- Domain entities (no suffix) live in `app/models/entities.py` — e.g. `Choice`, `UserQuestionState`, `LessonSession`

**Frontend (Dart) files:**
- `snake_case.dart` — e.g. `api_client.dart`, `lesson_summary_screen.dart`, `bottom_nav_bar.dart`
- Screens suffixed `_screen.dart` in `lib/screens/`; reusable UI suffixed by widget kind in `lib/widgets/`

**Frontend classes/types:**
- `PascalCase` — e.g. `ApiClient`, `CertificationOverview`, `LessonSummaryScreen`
- Model classes mirror backend response schema names minus `Response` suffix — e.g. `CertificationOverviewResponse` (backend) → `CertificationOverview` (`lib/models/certification.dart`)

**Frontend functions/variables:**
- `camelCase` — e.g. `getCertifications`, `overallMasteryPct`, `startLesson`
- JSON keys stay `snake_case` (mirroring the Python API) and are explicitly mapped to `camelCase` fields in `fromJson` factories — e.g. `json['overall_mastery_pct']` → `overallMasteryPct`

## Code Style

**Backend formatting/linting:**
- No formatter/linter config found (no `ruff.toml`, `.flake8`, or `black` config in `backend/pyproject.toml`) — style is consistent by convention/discipline, not tooling
- Docstrings in Portuguese, module-level, explaining the "why" and referencing spec docs (e.g. `docs/core-loop-srs.md`, `docs/system-design.md`, requirement IDs like `RF-04`, `RNF-06`)
- Type hints used throughout function signatures, including modern `|` union syntax (`date | None`, `dict | None`)
- `@dataclass(frozen=True)` used for all domain entities and pure-motor state objects — immutability is a deliberate pattern (see `app/models/entities.py`, `app/motor/srs.py`)

**Frontend formatting/linting:**
- `flutter_lints: ^6.0.0` via `analysis_options.yaml` (`frontend/analysis_options.yaml`) — default Flutter recommended rule set, no custom rules added
- `dart format` conventions (trailing commas, 2-space indent) followed throughout

## Comments & Documentation

**Backend:**
- Every module has a leading Portuguese docstring explaining purpose and linking to spec docs or requirement IDs (`RF-XX`, `RNF-XX`) — see `app/auth.py`, `app/motor/srs.py`, `app/repository/catalog.py`
- Comments explain **why**, not what — e.g. `app/services/answer_service.py:37-39` explains why "new" vs "review" is determined independently from the SRS motor's own state
- Non-obvious business rules get inline comments referencing the governing doc (e.g. `docs/core-loop-srs.md`, `docs/architecture-decisions.md`)

**Frontend:**
- Dart doc comments (`///`) on model classes reference the backend schema they mirror — e.g. `/// Espelha CertificationOverviewResponse em backend/app/routers/schemas.py` (`lib/models/certification.dart:1`)
- Method-level `///` comments cite the HTTP route and requirement ID — e.g. `/// GET /me — RF-01.` (`lib/api/api_client.dart:53`)

## Error Handling

**Backend:**
- Domain/service layer raises plain `ValueError` for invalid input or not-found conditions — e.g. `app/services/answer_service.py:34`, `app/services/session_service.py:46,60`
- Routers catch `ValueError` at the boundary and translate to `HTTPException` with the correct status code — pattern used consistently:
  ```python
  try:
      result = answer_service.answer_question(...)
  except ValueError as exc:
      raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
  ```
  (`app/routers/answer.py:26-35`)
- Auth failures raise `HTTPException` directly inside `app/auth.py` (401 for missing/invalid token, 500 if `SUPABASE_URL` misconfigured) — always with `from exc` to preserve the exception chain
- No generic catch-alls; exceptions bubble up as 500s if not explicitly handled — errors are not swallowed

**Frontend:**
- HTTP client layer throws a single custom exception type, `ApiException(statusCode, body)`, whenever a response status is outside 2xx (`lib/api/api_client.dart:46-51`, `lib/api/api_exception.dart`)
- No retry/backoff logic — a failed call throws immediately and the caller (screen) is responsible for catching and rendering error state

## Function Design

**Backend:**
- Pure business logic (`app/motor/*.py` — SRS, mastery, XP) takes only value objects and primitives, has zero I/O, and returns new immutable state — never mutates input. Explicitly documented as a design constraint (e.g. `app/motor/srs.py:1-11`: "Lógica de negócio pura: sem I/O, sem banco, sem relógio")
- Service layer (`app/services/*.py`) is where I/O, motor calls, and persistence meet — always takes `db: Session` as first positional arg, then keyword-only arguments (`*,`) for the rest, e.g. `answer_question(db, *, user_id, question_id, choice_id, now)` (`app/services/answer_service.py:24-31`)
- `now: datetime` is always passed in explicitly by the caller (router), never computed inside services/motor — keeps business logic testable without mocking the clock
- Repository functions (`app/repository/*.py`) are thin, single-purpose data-access functions returning domain entities, not ORM objects

**Frontend:**
- `ApiClient` methods are one-per-endpoint, each documented with the HTTP method/path and requirement ID, each returning a typed model via `Model.fromJson(...)` (`lib/api/api_client.dart`)
- Private helpers (`_getJson`, `_postJson`, `_decodeOrThrow`) centralize header/serialization/error-decoding logic reused across public methods

## Module Design

**Backend layering (strict, one-directional dependency):**
```
routers/  → services/  → repository/  → motor/ (pure)
                       ↘ models/entities.py (shared domain types)
```
- `app/models/entities.py` is the domain "source of truth" — both `app/repository/orm_models.py` (persistence) and `app/routers/schemas.py` (API wire format) must map TO these entities, never the reverse (documented explicitly, `app/models/entities.py:4-7`)
- `app/motor/` (srs.py, mastery.py, xp.py) has no dependency on any other app module — verifiable by import graph
- Routers depend on `app/routers/deps.py` for shared dependencies (`get_current_app_user`) and `app/auth.py` for JWT validation

**Frontend module design:**
- `lib/api/` — single `ApiClient` class wraps all HTTP calls
- `lib/models/` — one file per response shape, each with a `fromJson` factory
- `lib/screens/` — one file per full-screen route
- `lib/widgets/` — reusable, screen-agnostic UI components
- `lib/auth/auth_gateway.dart` — auth/session abstraction, separate from `ApiClient`
- No barrel files (no `index.dart`/re-export files) — imports are direct relative paths

---

*Convention analysis: 2026-08-11*
