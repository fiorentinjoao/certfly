# Pitfalls Research

**Domain:** SQLite→Supabase Postgres migration, authorization retrofitting, exam-content authoring at scale, mid-project TDD/SDD adoption (FastAPI + SQLAlchemy + Flutter solo project)
**Researched:** 2026-08-11
**Confidence:** HIGH (a, b, d — well-documented, cross-checked patterns); MEDIUM (c — less codified, more domain-judgment-based)

## Critical Pitfalls

### Pitfall 1: Supabase pooled connection (port 6543 / Supavisor transaction mode) breaks SQLAlchemy prepared statements

**What goes wrong:**
The app connects fine in local dev/testing, then in production (or as soon as `DATABASE_URL` points at Supabase's pooler on port 6543) intermittently throws `DuplicatePreparedStatementError` / `prepared statement "__asyncpg_stmt_N__" does not exist` under any concurrent load. It looks like a flaky, unreproducible bug rather than a config issue, and it will not show up in local testing against SQLite or a direct Postgres connection.

**Why it happens:**
Supabase's pooler (Supavisor, PgBouncer-compatible) runs in transaction-pooling mode by default. In that mode, a "connection" from the client's perspective is actually multiplexed across many physical Postgres connections mid-session, so server-side prepared statements (which SQLAlchemy/asyncpg/psycopg create automatically for parameterized queries) become invalid the moment the underlying connection changes. This is invisible during CertFly's current SQLite-only dev/test loop and won't be caught until real traffic hits Postgres.

**How to avoid:**
- Decide up front which connection string to use for the app: Supabase's **direct connection** (port 5432, no pooling — fine for a single backend instance) or the **pooler** (port 6543) with prepared statements explicitly disabled.
- If using the pooler with SQLAlchemy: set `statement_cache_size=0` (asyncpg) or the psycopg2/psycopg3 equivalent, and disable SQLAlchemy's own statement caching for that engine (`create_engine(..., connect_args={"prepared_statement_cache_size": 0})` for asyncpg-style dialects, or use `NullPool`).
- If using the **session pooler** or a low connection budget, tune `pool_size`/`max_overflow` conservatively — Supabase free/small-tier Postgres has a hard cap on concurrent connections shared across the pooler.
- Add this to the Postgres-migration phase's Definition of Done: "verified against Supabase pooler under >1 concurrent request," not just "app boots and one query works."

**Warning signs:**
- Works locally, works on first request in prod, then errors appear only under concurrent/burst traffic.
- Error text mentions `prepared statement ... already exists` or `does not exist`.

**Phase to address:**
SQLite → Supabase Postgres migration phase (connection/config sub-step), before any load or integration testing is considered complete.

---

### Pitfall 2: Silent data-type and constraint drift between SQLite and Postgres

**What goes wrong:**
SQLite is dynamically typed and permissive (it will happily store a string in an `INTEGER` column, silently truncate/coerce booleans, and has no real `ENUM`, `UUID`, or strict `NUMERIC` types). Code and ORM models built and tested exclusively against SQLite (as CertFly's test suite currently is — `backend/tests/integration/conftest.py` uses in-memory SQLite for 100% of tests) can pass every test and still fail against Postgres because Postgres enforces column types, `NOT NULL`, and foreign-key constraints strictly. Common CertFly-relevant risks: UUID columns stored as `TEXT` in SQLite that need to become native `uuid` in Postgres; datetime columns without explicit timezone handling (SQLite stores as text, Postgres `timestamptz` vs `timestamp` behave differently for the fixed-clock tests documented in TESTING.md); default values or server-side defaults (`func.now()`) that behave differently across dialects.

**Why it happens:**
Teams treat "the ORM abstracts the database" as true when it only abstracts syntax, not semantics — type coercion, constraint enforcement, and default-value timing differ per dialect. Since CertFly has zero Postgres-dialect test runs today (per CONCERNS.md), this drift has never been exercised.

**How to avoid:**
- Before writing migration code, audit every column in `orm_models.py` for dialect-sensitive types (UUID, boolean, datetime/timezone, JSON, enums) and pick explicit SQLAlchemy types (`sa.Uuid`, `sa.DateTime(timezone=True)`, `sa.Enum` bound to a Postgres native enum or a checked `String`) rather than relying on generic types that map loosely on SQLite.
- Stand up a real (or Dockerized) Postgres instance for local dev/test — not just for production — and run the full existing test suite against it before considering the migration done. This directly closes the "No Postgres-dialect test run" gap flagged in CONCERNS.md.
- Since there's no Alembic yet (`Base.metadata.create_all` only), generate the *first* Alembic migration by diffing against the actual current Postgres schema (if any data already exists) rather than assuming a clean slate — the "Fix approach" already implied in CONCERNS.md's Alembic tech-debt entry.

**Warning signs:**
- Any column touching UUIDs, timestamps, or booleans that was never explicitly typed in the model (relying on `String`/`Integer` defaults).
- Test suite is 100% green but has never run against anything but `sqlite:///:memory:`.

**Phase to address:**
SQLite → Postgres migration phase — specifically the schema/type-audit step, before data migration or Alembic baseline generation.

---

### Pitfall 3: Introducing Alembic for the first time on a schema that already diverged in production

**What goes wrong:**
CertFly has no migration tool today — schema is created via `Base.metadata.create_all()` on every startup (CONCERNS.md). The natural move is "add Alembic," but if Alembic's initial revision is auto-generated against an *empty* target DB while a differently-shaped SQLite schema (or a partially-seeded Supabase Postgres instance from earlier manual testing) already exists, the first `alembic upgrade head` either fails on `already exists` errors or silently diverges from what's actually running.

**Why it happens:**
`autogenerate` compares the target DB's *current* state to the models — if the target DB is not in the state the team assumes (e.g., someone already ran `create_all` against Supabase once during earlier testing), the generated migration is wrong from day one, and every future migration built on top of it inherits the same drift.

**How to avoid:**
- Before generating the first Alembic revision, decide and document what the "baseline" Postgres state actually is (empty vs. already has `create_all`-created tables from earlier manual runs) and pick one: either drop/recreate a clean Supabase Postgres schema and generate a real baseline, or `alembic stamp head` against the existing `create_all`-produced schema to mark it as the baseline without re-running DDL.
- Remove or gate the `Base.metadata.create_all(bind=engine)` call in `main.py` once Alembic is introduced — leaving both active means schema drift can reappear at any deploy.

**Warning signs:**
- `alembic upgrade head` throws "relation already exists" on first run.
- Any manual `psql`/Supabase-console schema edits that were never captured in a migration.

**Phase to address:**
SQLite → Postgres migration phase, immediately after connection config is verified (Pitfall 1) and before content-expansion work starts writing new tables/columns.

---

### Pitfall 4: Retrofitted ownership checks that fix the two known endpoints but leave the pattern unenforced everywhere else

**What goes wrong:**
The two identified gaps (`POST /topic/{id}/lesson` unlock check, `POST /lesson-session/{id}/complete` ownership check) get patched as one-off `if` statements inside their specific service functions. The fix works for those two endpoints, but the *pattern* — "any lookup-by-ID must also filter by/verify `user_id`" — isn't captured anywhere reusable, so the next endpoint added during content-expansion or feature work (e.g., a future "switch certification" or "delete my progress" endpoint) reintroduces the same class of bug.

**Why it happens:**
Retrofitting authorization is inherently piecemeal: a valid JWT proves *identity*, not *entitlement* to the specific resource ID in the URL/body, and nobody writes the `AND user_id = ?` clause unless a convention forces it. This is exactly the class of bug already found twice in CertFly (topic-unlock, lesson-session ownership) — it's a pattern, not two unrelated bugs.

**How to avoid:**
- Fix at the repository layer, not just the service layer: any repository function that fetches a row by primary key for a mutation (e.g., `lesson_sessions.get`/`complete`) should require and filter by `user_id` in the query itself (`WHERE id = :id AND user_id = :user_id`), returning "not found" (404) rather than "found but forbidden" (403) to avoid leaking existence of other users' resources — the standard IDOR-safe response pattern.
- Write ONE regression test per authorization rule that asserts cross-user access is rejected, and — per CertFly's existing testing convention (Portuguese-sentence-named regression tests documenting fixed bugs, e.g., `test_gate_destrava_o_proximo_topico_nao_o_atual`) — name them so they read as a checklist (e.g., `test_completar_sessao_de_outro_usuario_retorna_403`).
- Add a lightweight checklist/convention to CLAUDE.md or a CONTRIBUTING note: "every new endpoint that accepts a resource ID must have an explicit ownership/entitlement test," so this isn't re-discovered manually in a future audit.

**Warning signs:**
- A new endpoint added later accepts `{resource}_id` in the path/body and the PR has no accompanying "wrong owner → 403/404" test.
- Ownership check exists in the service function but the underlying repository query still fetches by ID alone (defense-in-depth missing at the data layer).

**Phase to address:**
Security-gaps-fix phase — the fix itself should be structured as: (1) repository-layer query change, (2) service-layer defense either removed as redundant or kept as documentation, (3) regression test, (4) short written convention captured for future endpoints (feeds into the SDD/TDD adoption phase).

---

### Pitfall 5: Content authored "from official exam guides" drifts from the source without anyone noticing

**What goes wrong:**
Scaling from 8-15 to 50-80 questions per certification, sourced from official exam guides (AWS DEA-C01, Azure DP-700, GCP PDE), commonly goes wrong in two ways: (1) the exam guide is a *topic outline* (domains/weightings), not a question bank — so "sourced from the official exam guide" gets quietly reinterpreted as "topics inspired by the guide, but question wording/scenarios written from memory or general knowledge of the service," introducing factual drift (deprecated service names, outdated pricing tiers, wrong default limits) that isn't caught because there's no source citation per question; (2) exam guides get updated by the vendor (AWS/GCP/Azure revise exam guides periodically, sometimes yearly) and content authored against an older guide version silently becomes stale with no mechanism to detect it.

**Why it happens:**
There is no per-question provenance field in the current YAML content model (per PROJECT.md, content is provider-agnostic YAML → seed loader), so "faithfulness to the official guide" is a one-time authoring intention, not a structurally enforced or auditable property. At solo-dev scale, authoring 50-80 questions × 3 certifications (150-240 questions) is enough volume that manual cross-checking against the guide for every question is unlikely to happen consistently without a forcing function.

**How to avoid:**
- Add a `source_guide_version` (and ideally `source_domain` matching the guide's official domain/task-statement numbering) field to the question YAML schema, populated at authoring time — this both forces the author to check the guide per question and creates an auditable trail for later re-verification when guides update.
- Snapshot the exam guide PDFs/versions used (date + version identifier, e.g., "AWS DEA-C01 exam guide, effective date X") in a `content/sources/` reference doc so future re-verification has a fixed target, and re-check content against the guide only when the vendor publishes a new version — not on an arbitrary schedule.
- Avoid copying verbatim phrasing, scenario text, or proprietary sample questions from vendor materials (copyright risk) — the exam guides list *topics/domains/weightings*, which are facts and not copyrightable; original questions must be *authored* against those topics, not lifted or lightly paraphrased from vendor practice exams or the guide's own example items (some guides include a few sample questions — these are the highest-risk copy targets).
- Given content volume (150-240 questions) and solo-dev constraint, budget authoring as a distinct, trackable phase with a per-certification checklist (all domains from the guide represented, weighting roughly matches the guide's stated domain percentages) rather than an open-ended "write more questions" task.

**Warning signs:**
- Questions reference specific numeric limits, pricing, or default configuration values without a way to trace which guide section/version justified them.
- No content review step exists before questions go live — same person authors and "verifies" with no external check.
- Domain distribution of authored questions doesn't roughly track the official guide's stated domain weightings (e.g., a domain that's 30% of the real exam has 5% of the question bank).

**Phase to address:**
Content-expansion phase — the schema/provenance-field change should land *before* bulk authoring starts, not retrofitted after 150+ questions exist.

---

### Pitfall 6: TDD/SDD adoption stalls the project because it's applied uniformly instead of risk-weighted

**What goes wrong:**
"Adopt TDD/SDD going forward" gets interpreted as "write specs and tests first for everything," including low-risk, fast-iterating UI/Flutter screen work — which slows a solo developer down disproportionately relative to the risk being mitigated, causes frustration, and the practice gets silently abandoned within a few weeks (a very common failure mode when TDD is introduced mid-project without calibrating where it pays off).

**Why it happens:**
TDD's payoff is highest for logic with clear inputs/outputs and regression risk (CertFly's SRS/mastery/XP motor is a textbook example — and per TESTING.md, this is exactly where the existing unit tests already live) and lowest for UI layout, one-off scripts, or exploratory work. Applying it uniformly ignores that CertFly's own existing test suite already demonstrates the right split: `backend/tests/unit/` for pure motor logic, `backend/tests/integration/` for DB+API behavior, and *no* tests at all for the Flutter frontend beyond the default smoke test (per TESTING.md) — that asymmetry is a reasonable reflection of where regressions are costly, not a gap to eliminate uniformly.

**How to avoid:**
- Scope "TDD/SDD going forward" explicitly: write tests first for backend business logic (services, repository queries with authorization/gating rules, SRS/mastery/XP calculations) where a regression would corrupt user progress data; treat Flutter UI work and one-off content-authoring scripts as "test-after or test-never, but code-reviewed," rather than mandating red-green-refactor everywhere.
- For "SDD," reuse the GSD phase-plan artifact itself as the spec — each phase's PLAN.md acts as the spec-before-code step already, so this doesn't need a separate new ceremony; the actual change is discipline in *following* it, not inventing new process overhead.
- Since there's no coverage tool active yet (per TESTING.md — "no coverage enforced"), avoid immediately imposing a hard coverage percentage gate; instead require "every new/changed service function touching auth, gating, or scoring has at least one test asserting its authorization/business rule," which is enforceable and directly targets the two known gaps.
- Keep the fixed-clock testing convention already in place (`TODAY`/`NOW` passed explicitly, never mocked via `freezegun`/monkeypatching) — it's a good existing pattern and TDD adoption should extend it, not replace it with a heavier framework.

**Warning signs:**
- New PRs start including large spec documents for trivial UI tweaks (over-application).
- Test-first discipline is followed for the first phase, then quietly dropped by the third (under-commitment because it wasn't scoped to where it actually pays off).
- Coverage numbers are tracked but the two known security gaps (unlock gate, ownership check) still don't have regression tests — a sign TDD effort is going to the wrong places.

**Phase to address:**
Should be stated explicitly as a working agreement at the start of the security-gaps-fix phase (where it has the highest immediate payoff — both known gaps are exactly the kind of authorization-rule logic TDD is good at) and carried forward as convention, not as a separate dedicated phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|--------------------|-----------------|------------------|
| Skip Dockerized/local Postgres, test only against SQLite as today | Faster local dev loop, no new infra | Postgres-only bugs (type coercion, pooler behavior) ship untested | Never once migration phase starts; acceptable only in current pre-migration state |
| Patch the two known authorization gaps as inline `if` checks without a repository-layer convention | Fast, minimal-diff fix | Same bug class recurs on next new ID-accepting endpoint | Only if paired with a written convention + regression test naming pattern (see Pitfall 4) |
| Author content without a `source_guide_version` field, add provenance later | Faster initial authoring | Expensive full-audit retrofit once 150+ questions exist and guide updates | Never at this volume — add the field before bulk authoring |
| Apply TDD uniformly across backend and Flutter frontend | Simple, one rule for everyone | Slows solo dev disproportionately on low-risk UI work, risks abandonment | Never — scope by risk (see Pitfall 6) |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|------------------|--------------------|
| Supabase pooler (Supavisor/PgBouncer transaction mode, port 6543) | Using default SQLAlchemy/asyncpg config, hitting prepared-statement errors under concurrency | Use direct connection (5432) for a single backend instance, or explicitly disable prepared statement caching (`statement_cache_size=0` / `NullPool`) if using the pooler |
| Supabase Postgres connection limits | Setting a large `pool_size`/`max_overflow` assuming dedicated Postgres capacity | Check the actual Supabase plan's connection cap; keep pool size conservative, prefer pooler for many short-lived connections, direct for one long-lived backend process |
| Alembic against an already-`create_all`'d Supabase schema | Auto-generating the first revision blind, assuming empty DB | Explicitly decide baseline state; use `alembic stamp head` if schema already exists, or reset schema cleanly first |
| Official exam-guide PDFs (AWS/GCP/Azure) | Treating guide's own sample questions or scenario phrasing as safe to lightly paraphrase | Author original scenarios/questions against the guide's *topic list and weightings* only; never copy/lightly-edit vendor sample questions |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| N+1 mastery computation (already documented in CONCERNS.md) — worsens once content triples (50-80 Q/cert vs 8-15) | `GET /certifications` and `/progress` latency grows with topic count | Batch SRS-state/question-ID fetch per certification before content expansion ships | Becomes noticeable once topic count per cert roughly triples alongside question count |
| Testing exclusively against in-memory SQLite while content volume grows | Query patterns that are fine on SQLite's simpler planner behave differently on Postgres at 150-240 rows/cert | Run integration suite against real Postgres once migration lands, especially the mastery/progress N+1 paths | As soon as Postgres migration completes; compounds with content-expansion volume |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Fixing ownership check only in service layer, not repository/query layer | Future endpoint reintroduces the same IDOR-class bug | Filter by `user_id` at the query level (`WHERE id = :id AND user_id = :user_id`), return 404 not 403 for not-owned resources |
| Leaving `SUPABASE_JWT_SECRET`-driven HS256 fallback with no runtime guard (per CONCERNS.md) | Accidental production misconfiguration silently disables real Supabase JWKS/ES256 verification | Add a startup assertion: refuse to boot (or log loudly) if `SUPABASE_JWT_SECRET` is set alongside a production-environment flag |
| Introducing Postgres without also adding `CORSMiddleware` before any web/admin client is added (per CONCERNS.md) | Not a migration blocker today, but easy to forget once Postgres unblocks external testing/web clients | Track as an explicit follow-up trigger: "add CORS config the moment a browser-based client is introduced," not bundled silently into the Postgres phase |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Content-authoring focuses on hitting a question *count* target (50-80/cert) rather than matching the guide's domain weighting | Some exam domains over-represented, others under-covered relative to the real exam, undermining the "exam-faithful prep" value proposition | Track authored-question count *per official exam-guide domain*, not just total per certification |
| Migration downtime/data loss risk for the solo dev's own existing SQLite progress data (if any exists beyond dev machine per PROJECT.md) | Loss of trust if "my streak/progress" data disappears during migration | Confirm whether any real user data exists pre-migration (per PROJECT.md, currently dev-machine-only) — if none, this is low risk now but should be a documented one-time check, not assumed |

## "Looks Done But Isn't" Checklist

- [ ] **Postgres migration:** Often missing — a real Postgres-backed run of the *entire* existing test suite (not just "the app starts and one manual request works"); verify by running `backend/tests/integration/` against Supabase Postgres, not SQLite.
- [ ] **Ownership/unlock-gate fixes:** Often missing — a regression test that actually attempts the forbidden action as a *second, different* authenticated user (not just checking the happy path still works); verify a `test_..._retorna_403` (or 404) exists for each gap.
- [ ] **Content expansion:** Often missing — per-question traceability to a specific exam-guide section/version; verify a sample of new questions can be mapped back to the guide without the original author's memory.
- [ ] **Alembic introduction:** Often missing — removal/gating of the old `Base.metadata.create_all()` call in `main.py`; verify only one schema-management mechanism is active, not both.
- [ ] **TDD/SDD adoption:** Often missing — explicit scope boundary (backend business logic vs. Flutter UI vs. one-off scripts); verify there's a written one-paragraph convention, not just "we do TDD now."

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|-----------------|------------------|
| Prepared-statement errors discovered in production after migration | LOW | Switch connection string to direct port 5432, or add `statement_cache_size=0`/`NullPool` config; no data impact, config-only fix |
| Data-type drift discovered after Postgres migration (e.g., UUID stored as text) | MEDIUM | Alembic migration to alter column type with explicit `USING` cast; requires a maintenance window if data already exists in production |
| Authorization gap found in a *new* endpoint post-launch (pattern not generalized) | MEDIUM | Patch at repository layer immediately, backfill regression test, audit all other ID-accepting endpoints in one pass rather than waiting for more reports |
| Content factual drift discovered after publishing (exam guide updated, question now stale) | MEDIUM-HIGH | Requires manual re-verification per question against new guide version — cost scales with how many questions lack a `source_guide_version` field; this is why the field should exist before bulk authoring |
| TDD/SDD adoption abandoned after a few weeks | LOW | Re-scope explicitly to backend business logic only (per Pitfall 6) rather than trying to re-impose a uniform rule; low cost to restart if scoped correctly this time |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|--------------------|----------------|
| Supabase pooler prepared-statement errors | Postgres migration phase | Load-test / concurrent-request check against real Supabase pooler before sign-off, not just single-request smoke test |
| SQLite↔Postgres type/constraint drift | Postgres migration phase | Full existing test suite passes against real Postgres, not just SQLite |
| Alembic baseline mis-generated against divergent schema | Postgres migration phase | `alembic upgrade head` runs cleanly on a freshly-provisioned Supabase instance AND `alembic stamp head` path is documented for any pre-existing schema |
| Authorization retrofit fixes symptom not pattern | Security-gaps-fix phase | Repository-layer `user_id` filtering in place for both known gaps; regression test exists for each; written convention captured for future endpoints |
| Content factual drift / no provenance | Content-expansion phase | `source_guide_version` field present on 100% of new questions; domain-weighting spot-check against official guide before marking a certification's content "done" |
| TDD/SDD applied uniformly, stalls momentum | Security-gaps-fix phase (where it starts) and carried forward | One-paragraph written scope agreement exists distinguishing backend-business-logic-first vs. UI test-after; revisit at next milestone boundary per PROJECT.md's phase-review protocol |

## Sources

- [Supabase Pooling and asyncpg Don't Mix — Medium](https://medium.com/@patrickduch93/supabase-pooling-and-asyncpg-dont-mix-here-s-the-real-fix-44f700b05249) — MEDIUM confidence (community blog, cross-checked against Supabase's own docs/GitHub issues below)
- [Python asyncpg burst-request prepared statement errors — supabase/supabase#39227](https://github.com/supabase/supabase/issues/39227) — HIGH confidence (official repo issue tracker)
- [`PreparedStatementError` using asyncpg and sqlalchemy — supabase/supabase#35684](https://github.com/supabase/supabase/issues/35684) — HIGH confidence
- [Supabase Docs — Disabling Prepared Statements](https://supabase.com/docs/guides/troubleshooting/disabling-prepared-statements-qL8lEL) — HIGH confidence (official docs)
- [Alembic for maintaining schema across SQLite/Postgres — sqlalchemy/alembic Discussion #1009](https://github.com/sqlalchemy/alembic/discussions/1009) — HIGH confidence (official project discussion)
- [Insecure Direct Object Reference (IDOR) — Authgear](https://www.authgear.com/post/idor-insecure-direct-object-reference/) — MEDIUM confidence (vendor security blog, consistent with OWASP guidance)
- [How to Fix Broken Object Level Authorization in REST APIs — how2](https://how2.sh/posts/how-to-fix-broken-object-level-authorization-in-apis/) — MEDIUM confidence
- [Introducing TDD to Teams / TDD anti-patterns — IEEE](https://ieeexplore.ieee.org/document/10211890) — MEDIUM confidence (peer-reviewed, referenced via search summary)
- `.planning/codebase/CONCERNS.md` — HIGH confidence (first-party codebase audit, directly informs Pitfalls 1-4)
- `.planning/codebase/TESTING.md` — HIGH confidence (first-party codebase audit, directly informs Pitfalls 2, 6)
- `.planning/PROJECT.md` — HIGH confidence (first-party project scope document)

---
*Pitfalls research for: CertFly — Postgres migration, security fixes, content scale-up, TDD/SDD adoption milestone*
*Researched: 2026-08-11*
