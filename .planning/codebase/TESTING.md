# Testing Patterns

**Analysis Date:** 2026-08-11

Only the backend (`backend/`) has an active, non-trivial test suite. The
frontend (`frontend/`) has a single default Flutter smoke test.

## Test Framework

**Backend:**
- Runner: `pytest >= 8.3` (`backend/pyproject.toml`)
- HTTP testing: `httpx >= 0.27` (used via FastAPI's `TestClient`)
- Config: `[tool.pytest.ini_options]` in `backend/pyproject.toml` — `testpaths = ["tests"]`
- No coverage tool configured (no `pytest-cov`, no coverage threshold enforced)

**Run commands:**
```bash
cd backend
.venv/bin/python -m pytest              # run full suite (unit + integration)
.venv/bin/python -m pytest tests/unit   # unit only
.venv/bin/python -m pytest tests/integration  # integration only
```
(commands documented in root `README.md`)

**Frontend:**
- Runner: `flutter_test` (bundled with Flutter SDK), declared in `frontend/pubspec.yaml`
- Run: `flutter test` (standard Flutter command; no custom config found)

## Test File Organization

**Backend — two-tier split:**
```
backend/tests/
├── unit/           # pure business logic — no DB, no I/O
│   ├── test_entities.py
│   ├── test_mastery.py
│   ├── test_srs.py
│   └── test_xp.py
└── integration/    # DB + API — exercises real SQLAlchemy/FastAPI wiring
    ├── conftest.py
    ├── test_api.py         # full HTTP request/response cycle via TestClient
    ├── test_repository.py  # repository layer against real (in-memory) DB
    └── test_services.py    # service layer against real (in-memory) DB
```
- Naming: `test_<module_or_concern>.py`, one file per motor module in `unit/`
- `unit/` tests import directly from `app.motor.*` — zero DB/session setup required
- `integration/` tests always go through a DB session fixture or the FastAPI `TestClient`

**Frontend:**
- `frontend/test/widget_test.dart` — single file, default Flutter test naming (`*_test.dart`)

## Test Structure

**Backend unit test pattern** (`backend/tests/unit/test_mastery.py`):
```python
def test_recall_no_exato_dia_do_intervalo_e_meio():
    p = probability_of_recall(interval_days=3, days_since_last_review=3)

    assert p == 0.5
```
- Test names are full Portuguese sentences describing the behavior under test (e.g. `test_topico_nao_destrava_com_amostra_pequena_mesmo_com_100_por_cento`) — self-documenting, no docstrings needed on individual tests
- One blank line between the "act" line and the `assert` — consistent visual separation of arrange/act vs. assert
- Grouped with `# --- section name ---` comment banners inside a single file when testing multiple functions from the same module

**Backend integration test pattern** (`backend/tests/integration/test_services.py`, `test_api.py`):
- Arrange: build a small content graph (Provider → Certification → Domain → Topic → Question → Choice) using either the `seed_topic` fixture factory or a local `_seed_topic_with_question()` helper
- Act: call the service function or hit the endpoint via `TestClient`
- Assert: check both the returned result AND side effects (DB state, XP, streak) in the same test

## Mocking

**Backend — no mocking framework used.** Integration tests run against a real (in-memory SQLite) database instead of mocking the ORM/repository layer:
```python
@pytest.fixture()
def db_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    session_local = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    session = session_local()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()
```
(`backend/tests/integration/conftest.py:28-39`)

- For full-stack API tests, FastAPI dependency overrides swap `get_db` and `get_current_user` — real DB session (StaticPool + `check_same_thread=False` so all TestClient threadpool threads share the same in-memory DB), and a fake authenticated user (`FAKE_USER_ID`) instead of real JWT validation (`backend/tests/integration/test_api.py`)
- **What to "mock" here:** external boundaries only — auth (via dependency override) and the clock (`now: datetime` passed explicitly into services, never read from `datetime.now()` inside business logic)
- **What NOT to mock:** the database or ORM layer — tests always exercise real SQLAlchemy against real (in-memory) SQLite to catch schema/query bugs

**Frontend:**
- No mocking framework present (no `mockito`/`mocktail` dependency in `pubspec.yaml`)
- `ApiClient` accepts an optional `httpClient` in its constructor (`ApiClient({..., http.Client? httpClient})`, `lib/api/api_client.dart:22-23`) — designed for test injection of a fake `http.Client`, though no test currently exercises this

## Fixtures and Factories

**Backend:**
- `db_session` fixture (`conftest.py`) — fresh in-memory SQLite engine + session per test, torn down after
- `seed_topic` fixture factory (`conftest.py:42-96`) — builds a full Provider→Certification→Domain→Topic→N Questions graph; returns a `factory(n_questions, *, domain_order=1, topic_order=1)` callable reusable across any test needing populated catalog data
- `test_api.py` defines its own local `client()` fixture and `_seed_topic_with_question()` helper for HTTP-level tests, separate from the DB-session-level fixtures used by `test_services.py`/`test_repository.py`
- Test data uses `uuid.uuid4()` for all generated IDs/slugs to guarantee isolation between tests even when sharing table structure

**Frontend:**
- No fixtures/factories present; single smoke test needs none

## Coverage

**Requirements:** None enforced — no coverage tool configured for either stack.

## Test Types

**Unit tests (backend):** pure motor logic only — `probability_of_recall`, `topic_mastery_pct`, `is_topic_unlocked`, `apply_answer`, `xp_for_answer`, and entity dataclass construction. Zero I/O, zero DB, fast and deterministic.

**Integration tests (backend):** three layers, from lowest to highest:
1. `test_repository.py` — repository functions against a real DB session
2. `test_services.py` — service-layer orchestration (motor + repository together) against a real DB session, covering full lesson/answer/progress/session flows and edge cases (min sample size, last topic in certification, unlock regression)
3. `test_api.py` — full HTTP request/response cycle through `TestClient`, covering auth (401 on missing token), first-call user creation, complete lesson flow end-to-end, and response-shape guarantees (e.g. lesson response must NOT leak `is_correct`/`explanation` before answering)

**E2E tests:** Not used. No frontend-to-backend integration test exists — the Flutter app has no automated coverage beyond a config-missing smoke test.

## Common Patterns

**Fixed test clock (backend):**
```python
TODAY = date(2026, 8, 9)
NOW = datetime(2026, 8, 9, tzinfo=timezone.utc)
```
Services accept `now`/dates as explicit parameters, so tests pass a fixed constant instead of freezing real time (`backend/tests/integration/test_services.py`).

**Regression test as documentation:** at least one test in `test_services.py` exists specifically to lock in a fixed bug (topic-unlock logic was unlocking the *current* topic instead of the *next* one) — the test name and a comment document the original bug, serving as a guard against reintroduction.

**Response-shape security assertions (backend):** `test_api.py` explicitly asserts that answer-choice fields (`is_correct`, `explanation`) are absent from the lesson-generation response and present only after answering — testing information-leakage boundaries, not just status codes.

---

*Testing analysis: 2026-08-11*
