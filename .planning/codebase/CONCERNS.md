# Codebase Concerns

**Analysis Date:** 2026-08-11

## Tech Debt

**No database migration tool (MVP-stage schema management):**
- Issue: Schema is created via `Base.metadata.create_all(bind=engine)` on every app startup — idempotent for adding new tables/columns to an empty DB, but there is no Alembic (or equivalent) migration chain to evolve an existing Postgres schema safely (renames, column drops, data backfills).
- Files: `backend/app/main.py` (call site), `backend/app/repository/db.py` (engine setup), `backend/app/repository/orm_models.py` (models)
- Impact: Any schema change beyond additive `CREATE TABLE`/`ADD COLUMN` risks manual, unscripted intervention against the production Supabase Postgres instance.
- Fix approach: Introduce Alembic once schema changes go beyond additive changes; generate an initial migration matching current `orm_models.py` state.

**Topic-unlock gate enforced only for display, not for lesson start (server-side gate bypass):**
- Issue: `GET /certification/{id}/progress` computes `unlocked` for UI purposes (`backend/app/services/progress_service.py`), but `POST /topic/{id}/lesson` (`backend/app/services/lesson_service.py::start_lesson`) never checks whether the topic is unlocked for the calling user before generating a lesson session. Any authenticated user can start a lesson (and earn XP/SRS progress) on a topic that is still locked in the UI, simply by knowing/guessing its `topic_id`.
- Files: `backend/app/services/lesson_service.py`, `backend/app/routers/lesson.py`, `backend/app/services/progress_service.py`
- Impact: Progression gating (RF-09) is a client-side/UI-only guarantee, not enforced by the API. A modified client (or direct API call) can skip the sequential-unlock design entirely.
- Fix approach: Add an unlock check in `start_lesson` (or as a FastAPI dependency) using the same `lesson_sessions.get_topic_progress` + entry-point logic already in `progress_service.get_certification_progress`, and return 403 if the topic is locked.

**N+1 mastery computation for multi-certification/progress endpoints:**
- Issue: `certifications_service.get_certifications_overview` calls `topic_mastery.compute(db, user_id, topic_id, today)` once per topic per certification, and each `compute` call issues its own `catalog.get_topic_question_ids` + `srs_state.get_all_for_topic` queries. `progress_service.get_certification_progress` does the same per topic within one certification.
- Files: `backend/app/services/certifications_service.py`, `backend/app/services/progress_service.py`, `backend/app/services/topic_mastery.py`
- Impact: `GET /certifications` and `GET /certification/{id}/progress` issue O(topics) round-trips to the database. Fine at MVP content volume (~a few dozen topics across 3 certifications) but will not scale as content grows.
- Fix approach: Batch-fetch SRS state and question IDs for all topics of a certification (or all certifications) in one or two queries, then compute mastery in-memory per topic.

**No ownership check on lesson-session completion (documented earlier as a fixed bug elsewhere — this is a separate, still-open gap):**
- Issue: `POST /lesson-session/{id}/complete` resolves the session purely by `session_id` (`lesson_sessions.get`/`complete` in `backend/app/repository/lesson_sessions.py`) and never verifies `session.user_id == user.id` from the authenticated caller (`backend/app/services/session_service.py::complete_lesson_session`).
- Files: `backend/app/services/session_service.py`, `backend/app/repository/lesson_sessions.py`, `backend/app/routers/lesson_session.py`
- Impact: If a `session_id` (UUID) is known or leaked, a different authenticated user could complete someone else's lesson session, updating *their own* streak/unlock state based on *another user's* session's XP sum. Low practical risk (UUIDs aren't guessable), but it's a missing authorization check, not just an edge case.
- Fix approach: In `session_service.complete_lesson_session`, assert `session.user_id == user_id` and raise a 403/404 if not.

**No CORS configuration on the FastAPI app:**
- Issue: `backend/app/main.py` never adds `CORSMiddleware`. Fine for the Flutter mobile app (no browser CORS enforcement) but would silently block any future web build or browser-based tooling hitting the API cross-origin.
- Files: `backend/app/main.py`
- Impact: Currently invisible because there is no web client in this codebase; becomes a blocker the moment a Flutter Web build or admin dashboard is added.
- Fix approach: Add `CORSMiddleware` with an explicit allowlist before shipping any web-facing client.

## Known Bugs

**Topic-unlock gate unlocking the wrong topic (FIXED):**
- Symptoms: Completing a lesson re-locked/re-marked the topic the user had *just finished* as unlocked, instead of unlocking the *next* topic in the trail — so the trail never progressed past the first topic.
- Files: `backend/app/services/session_service.py` (see inline comment at lines 76–83 documenting the fix directly in code)
- Fix: `complete_lesson_session` now calls `catalog.get_next_topic_id(db, session.topic_id)` and unlocks that result, not `session.topic_id` itself. Regression-tested by `test_gate_destrava_o_proximo_topico_nao_o_atual` in `backend/tests/integration/test_services.py`.
- Status: Fixed and covered by test. No further action needed.

## Security Considerations

**Dev-only HS256 auth fallback controlled by env var presence:**
- Risk: `backend/app/auth.py::_decode` accepts HS256 tokens signed with `SUPABASE_JWT_SECRET` whenever that env var is set, bypassing the real Supabase JWKS/ES256 verification. This is intentional (documented in the module docstring, used by `scripts/seed_dev.py` for local dev), and the `.env.example` warns "never set this in production."
- Files: `backend/app/auth.py`, `backend/.env.example`
- Current mitigation: Clear docstring/comment warning; production deployment is expected to only set `SUPABASE_URL`.
- Recommendations: There is no runtime assertion preventing `SUPABASE_JWT_SECRET` from being accidentally set in a production environment (e.g., copy-pasted `.env` file). Consider a startup check that refuses to boot with both `SUPABASE_JWT_SECRET` set and an environment flag indicating production, or logging a loud warning if HS256 fallback is enabled.

**Missing per-user authorization on `lesson-session` completion (see Tech Debt above):**
- Risk: Cross-user data manipulation via UUID guessing/leakage.
- Files: `backend/app/services/session_service.py`
- Current mitigation: UUIDs are not practically guessable; session IDs are not exposed in any public URL surface.
- Recommendations: Add explicit ownership check (see Tech Debt fix approach).

**OAuth debug logging via `debugPrint`:**
- Risk: `frontend/lib/screens/login_screen.dart` (`_signInWithGoogle`) logs OAuth callback URIs and error details via `debugPrint`. `debugPrint` is stripped in Flutter release builds by default, so production risk is low, but the callback URI could contain the OAuth `code` parameter during debug/profile builds.
- Files: `frontend/lib/screens/login_screen.dart` (lines ~129–152)
- Current mitigation: `debugPrint` no-ops in release mode.
- Recommendations: None required for MVP; avoid extending this logging to include tokens/secrets.

**Brand-asset trademark risk (acknowledged, not a code issue):**
- Risk: The app bundles official GCP/AWS/Azure logos (`assets/images/logo_gcp.png`, `logo_aws.png`, `logo_azure.png`) without documented authorization, per the comment in `frontend/pubspec.yaml`.
- Files: `frontend/pubspec.yaml`, `frontend/lib/screens/certifications_screen.dart`
- Current mitigation: Explicit, acknowledged product decision (comment: "decisão explícita do dono, ciente do risco").
- Recommendations: Revisit before any public app-store submission; provider brand guidelines typically restrict logo usage without a partnership agreement.

## Performance Bottlenecks

**Mastery computation N+1 (see Tech Debt above) — repeated here for cross-reference:**
- Problem: `GET /certifications` and `GET /certification/{id}/progress` scale linearly with per-topic DB round-trips.
- Files: `backend/app/services/certifications_service.py`, `backend/app/services/progress_service.py`, `backend/app/services/topic_mastery.py`
- Cause: `topic_mastery.compute` issues its own queries per topic instead of batching across topics.
- Improvement path: Batch `srs_state` fetch across all topics in a certification (or all certifications) in a single query keyed by topic, then slice in-memory.

## Fragile Areas

**`catalog.get_next_topic_id` trail-ordering logic:**
- Files: `backend/app/repository/catalog.py` (lines ~83–110)
- Why fragile: "Next topic" is derived purely from `TopicORM.order` within a domain, then `DomainORM.order` for cross-domain wraparound — this logic silently returns `None` (no unlock) if content authoring ever produces gaps, duplicate `order` values, or topics not assigned to a domain in the expected order. There is no validation at content-seed time enforcing contiguous ordering.
- Safe modification: When adding/reordering topics in content YAML (`content/*.yaml`) or the seed loader, verify `order` values are contiguous per domain and domains are contiguous per certification.
- Test coverage: Covered for the "last topic of last domain" and "unlock next not current" cases in `backend/tests/integration/test_services.py`, but not for gaps/duplicate `order` values.

**`start_lesson` selection window is a straight due-then-new slice with no shuffling:**
- Files: `backend/app/services/lesson_service.py`
- Why fragile: `selected_ids = (due_ids + new_ids)[:LESSON_SIZE]` preserves whatever order `catalog.get_topic_question_ids` returns (DB insertion/query order) — question order across lessons is deterministic and repetitive, not randomized, which could make lessons feel repetitive but is not a correctness bug.
- Safe modification: If randomization is desired, shuffle within `due_ids` and `new_ids` before slicing, preserving the due-first priority.
- Test coverage: `test_start_lesson_traz_ate_lesson_size_questoes_novas` and `test_start_lesson_prioriza_revisao_vencida_sobre_questoes_novas` cover selection priority, not ordering/randomization.

**Auto-provisioning `app_user` on every authenticated request:**
- Files: `backend/app/routers/deps.py` (`get_current_app_user` calls `users.get_or_create_user` on every request)
- Why fragile: Every authenticated endpoint performs a get-or-create against the `app_user` table. Not a correctness issue (documented intentionally to avoid requiring `/me` be called first), but it means user row creation isn't a single well-defined "signup" event — first-touch behavior on any endpoint. If `get_or_create_user` isn't atomic/idempotent under concurrent first requests (e.g., two simultaneous requests from a freshly-signed-up user), a race could raise a unique-constraint error.
- Safe modification: Check `backend/app/repository/users.py::get_or_create_user` implementation before assuming it's race-safe under concurrent first calls; add `ON CONFLICT DO NOTHING`-style handling if not already present.
- Test coverage: Not explicitly tested for concurrent first-call race conditions.

## Scaling Limits

**SQLite fallback for local dev/tests vs. Postgres in production:**
- Current capacity: Local/dev uses SQLite (`backend/certfly.db`) by default when `DATABASE_URL` is unset; production points to Supabase Postgres.
- Limit: Behavioral differences between SQLite and Postgres (e.g., type coercion, concurrency, `UPSERT` syntax) are not exercised by the test suite, since tests run exclusively against SQLite (`backend/tests/integration/conftest.py`). A Postgres-specific bug could ship untested.
- Scaling path: Consider running the integration suite against a real (or containerized) Postgres instance in CI, at least periodically, to catch dialect-specific issues.

## Dependencies at Risk

Not applicable — dependency set is small and current (FastAPI, SQLAlchemy, PyJWT, Flutter `http`/`supabase_flutter`). No pinned versions observed to be end-of-life or flagged as vulnerable during this review.

## Missing Critical Features

**No admin/content-authoring tool beyond YAML + seed script:**
- Problem: Content (`content/*.yaml`, loaded via `scripts/seed_dev.py`) is the only way to add certifications/domains/topics/questions. There is no runtime content-management UI or validation step ensuring `order` fields are contiguous or that certifications reference valid providers before seeding.
- Blocks: Non-technical content edits require direct YAML editing and awareness of the ordering fragility noted above.

**No certification switching/listing endpoint consumed everywhere it's needed (partially addressed):**
- Problem: `frontend/lib/screens/profile_screen.dart` has an explicit `onTap: null, // TODO: sem endpoint de listagem/troca de certificação ainda` — even though `GET /certifications` now exists (per `backend/app/routers/certifications.py`, added per recent commit history), the Profile screen's "switch certification" affordance is still wired to `null` and not yet connected to the new endpoint.
- Files: `frontend/lib/screens/profile_screen.dart` (line 124), `backend/app/routers/certifications.py`
- Blocks: Users cannot switch their active/tracked certification from the Profile screen yet, despite the backend now supporting certification listing.

## Test Coverage Gaps

**No test for server-side topic-unlock enforcement on lesson start:**
- What's not tested: Whether `POST /topic/{id}/lesson` rejects starting a lesson on a locked topic (because it currently doesn't — see Tech Debt above).
- Files: `backend/app/services/lesson_service.py`, `backend/tests/integration/test_services.py`
- Risk: A regression (or the current gap) allowing progression-gate bypass would not be caught by CI.
- Priority: Medium — ties directly to the RF-09 gate being a stated product requirement.

**No test for lesson-session ownership/cross-user access:**
- What's not tested: That `POST /lesson-session/{id}/complete` rejects completing another user's session.
- Files: `backend/app/services/session_service.py`, `backend/tests/integration/test_services.py`, `backend/tests/integration/test_api.py`
- Risk: The missing ownership check (see Security Considerations) has no regression test guarding a future fix or catching the current gap.
- Priority: Medium.

**No Postgres-dialect test run:**
- What's not tested: Any behavior that differs between SQLite (used in `backend/tests/integration/conftest.py`) and Postgres (used in production via Supabase).
- Files: `backend/tests/integration/conftest.py`, `backend/app/repository/db.py`
- Risk: A Postgres-only bug (type handling, concurrency, migrations) ships without CI coverage.
- Priority: Low for current MVP scale, worth revisiting before wider production traffic.

---

*Concerns audit: 2026-08-11*
