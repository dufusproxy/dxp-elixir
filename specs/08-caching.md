# 08 — Render Cache & Invalidation

**Priority:** Core (Phase 1, PR #10) · **Spec:** §6.3, §6.4, §7.3 · **Depends on:** 06, 07 · **Blocks:** dogfood deployment

## Goal

The render-and-cache pipeline — the system's primary performance mechanism. Most renders most of the time are cache hits; regeneration on miss is incremental static regeneration at the platform level.

## Design (spec §6.3)

- **Cache key:** `{asset_id, page_component_version, layout_component_version, child_component_versions, locale, audience_segment}` — different combinations produce different cached HTML.
- **Storage:** tier 1 in process memory (Cachex), tier 2 in Redis for larger horizons. CDN (Cloudflare) in front for the truly hot pages.
- **Invalidation:** Phoenix PubSub events from Ash actions trigger Oban workers that mark affected entries stale. Granular — updating an asset invalidates only pages that reference it.
- **Regeneration:** on miss, Phoenix re-renders using current component versions and writes back.
- **LiveView opts out:** live components render per session, never cached (by design — Phase 3).

## Tasks

- [ ] Cachex tier-1 cache with the composite key above.
- [ ] Redis tier-2 (optional in dev; required in prod topology).
- [ ] Reference tracking: know which cached pages reference which assets/components so invalidation can be granular.
- [ ] AshOban invalidation workers subscribed to domain events (asset mutations, component publishes).
- [ ] Regeneration-on-miss path writing back to both tiers.
- [ ] CDN integration hooks (cache-control headers; purge API for hard invalidations).
- [ ] Metrics: hit rate, regeneration latency, invalidation fan-out (feeds task 18 observability).

## Acceptance criteria

- PR #10 (spec §9.4): Cachex tier-1 + AshOban-driven invalidation on Ash domain events; static SSR site visibly served from cache.
- Updating one asset invalidates only the pages that reference it (verified by test).
- Publishing a component version invalidates exactly the subscribed, affected pages.
- Hot path targets (spec §7.3): P95 < 200 ms at origin on miss, P95 < 50 ms at edge on hit.

## Notes

- After this package plus 01–07, the system is "the smallest end-to-end DXP that renders real pages from authored content" (spec §9.4) — the Phase 1 dogfood milestone.
