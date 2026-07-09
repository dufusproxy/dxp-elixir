# 10 — Search

**Priority:** Core (Phase 2; foundations can start in Phase 1) · **Spec:** §7.2, §8.3 · **Depends on:** 02, 04 · **Blocks:** 16 (RAG search)

## Goal

Postgres full-text search via AshPostgres — good enough to compete with Funnelback for the 80% case, with a provider-agnostic indexing layer so Meilisearch can slot in later as a configuration change, not a rewrite. **No JVM in the standard architecture** (spec §7.2 reverses v1's OpenSearch decision).

## Tasks

### Phase 1–2: Postgres FTS

- [ ] `tsvector` calculations declared on searchable Ash resources via AshPostgres expressions.
- [ ] `pg_trgm` for fuzzy matching; `unaccent` for accent-insensitive search.
- [ ] Optional `pgvector` column for semantic search (groundwork for Phase 3 RAG).
- [ ] Indexing pipeline: AshOban workers subscribed to domain events keep indexes current on every mutation.
- [ ] Search API endpoint: query → Postgres FTS via Ash → response **with highlighting and facets**.
- [ ] Faceted search + search analytics (spec §8.3).
- [ ] Permission-aware results: search never leaks assets the actor can't read (uses task 03).

### Architecture: provider-agnostic indexing layer

- [ ] Define an indexing behaviour (`Core.Search.Provider`) so the Postgres implementation and a future Meilisearch implementation are swappable by config (spec §10: "switching is a configuration change, not a rewrite").

### Phase 3+ (deferred, see task 16)

- Meilisearch sidecar (single Rust binary, REST-driven) if Postgres FTS hits a wall on relevance tuning, scale, or complex faceting.
- OpenSearch only as a per-customer deployment option on demand — never in the standard stack.

## Acceptance criteria

- Search query hot path: **P95 < 100 ms** (spec §7.3).
- Sub-50ms typical FTS latency at target scales — universities with 50k pages, councils with a few hundred thousand documents (spec §7.2).
- Index stays consistent with content after create/update/archive (event-driven, verified by test).
