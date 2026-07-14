# 16 — Phase 3: Competitive Features

**Priority:** Phase 3 (~3 months) · **Spec:** §8.4, §5.4, §7.2 · **Depends on:** Phase 1–2 complete (01–13; 15 for client-hydrated modes) · **Blocks:** 17

## Goal

The features that move the platform from "DXP-shaped" to competitive against the incumbent set: full runtime modes, integrations (iPaaS, CDP), personalization, A/B testing, conversational search, and the public contract.

## Tasks

### Runtime modes 2–4 (spec §5.4, §8.4)

- [ ] **LiveView mode**: stateful process per session, server controls DOM — dashboards, complex forms. Opts out of the render cache by design.
- [ ] **Phoenix Channels + client hydration**: pub/sub, no per-session state, client controls DOM — live widgets with local state.
- [ ] **External + client hydration**: no server session; AJAX/third-party WS/GraphQL subs — components talking to other systems.
- [ ] Per-instance mode selection on pages fully honoured across render + cache layers.

### Integrations

- [ ] n8n (self-hosted) for iPaaS-shaped workflows; webhooks; connector library (spec §8.4 — closest OSS equivalent to Squiz Connect).
- [ ] RudderStack ingestion; audience segments; rules-based personalization (audience_segment is already in the cache key).
- [ ] A/B testing framework with edge personalization on Cloudflare Workers.

### Search upgrades (spec §7.2)

- [ ] Conversational AI search: RAG over the Postgres FTS index (+ pgvector).
- [ ] Meilisearch sidecar as an optional upgrade behind the provider-agnostic indexing layer (task 10) — configuration change, not a rewrite.

### Contract

- [ ] Public component contract specification published (versioning policy decision comes due here — spec §11).
- [ ] Decide Web Components interop: ship client-rendered components as custom elements **only at the consumption boundary**, not internally (open question, confirm before Phase 3 — spec §11).

## Acceptance criteria

- The same component runs static on one page and LiveView on another, per instance (spec §5.4's Card example).
- Personalized variants render correctly from cache (segment-keyed) and at the edge.
- Meilisearch can be enabled per deployment without code changes.
