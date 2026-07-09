# 06 — Component Runtime Loading

**Priority:** Core (Phase 1, PRs #7–8) · **Spec:** §6 · **Depends on:** 05 · **Blocks:** 07, 08

## Goal

How component artefacts get from a repo to running on the platform **without a platform redeploy**. Artefacts (HEEx template, JS bundle, CSS, manifest) are deployed as files to object storage and loaded at render time. Sites subscribe to component versions independently of the platform release cycle.

This package is pure Elixir: storage, records, loading, caching. It applies to Phoenix-native components in Phase 1 exactly as it will to Vite-compiled ones in Phase 2 — same artefact format, same pipeline.

## The artefact format (spec §6.2)

- `render_server.heex` — HEEx template **string**. Loaded via `Phoenix.LiveView.HTMLEngine`, compiled-to-AST once on first use, cached in ETS keyed by `{name, version}`. Stored as a string, **not** a precompiled BEAM module — avoids dynamic `:code.load_binary/3` entirely; cost is a few ms on first compile, sub-microsecond thereafter (spec §10).
- `render_client.js` — client hydration bundle, served via CDN, lazy-loaded (Phase 2 concern; slot exists from day one).
- `styles.css` — scoped CSS bundle, served via CDN, linked as `<link>`.
- `manifest.yaml` — the contract (task 05). Parsed once, cached as struct.

## The component pipeline (spec §6.1)

1. Author works in a Git repo (HEEx source in Phase 1; Astro/Vue via Vite plugin in Phase 2).
2. Artefact directory produced: `render_server.heex`, `render_client.js`, `styles.css`, `manifest.yaml`.
3. Sync uploads artefacts to the platform — CLI (`dxp deploy components/`) for iteration; Git webhook for CI/CD. Same outcome either way.
4. Platform validates the manifest, runs cycle-prevention static analysis on layout chains, stores artefacts in object storage under `tenants/{tenant_id}/components/{name}/{version}/...`, writes a `ComponentVersion` record.
5. Subscribed sites are notified; a domain event fires; an Oban worker invalidates affected cache entries.
6. Next request renders with the new version; result written to cache.

## Tasks

- [ ] Object storage integration (S3-compatible: MinIO locally, R2/S3 in prod) with per-tenant artefact paths.
- [ ] Upload/ingest endpoint: manifest validation → layout-chain cycle analysis → object storage write → `ComponentVersion` record (PR #7).
- [ ] `dxp deploy components/` CLI (thin Elixir escript or mix task acceptable in Phase 1).
- [ ] Git webhook ingest path producing the identical outcome.
- [ ] HEEx loader: fetch template string from object storage, compile via `Phoenix.LiveView.HTMLEngine`, cache AST in ETS keyed `{name, version}` (PR #8).
- [ ] Manifest struct cache (parse once).
- [ ] Publish → notify: domain event on new ComponentVersion; Oban worker marks affected cache entries stale (ties into task 08).
- [ ] Publish-time static analysis: layout chain must not transitively reference itself; cycles fail upload with a clear error (spec §5.6).

## Acceptance criteria

- Component publish hot path: CLI upload → validation → cycle analysis → storage → record → invalidation, **deploy-to-live < 30 seconds** (spec §7.3).
- First render after publish compiles from object storage; subsequent renders hit the ETS AST cache (sub-microsecond).
- A layout cycle in an uploaded chain is rejected at publish time with a structured error.

## Notes

- Storage shape summary (spec §6.4): artefacts → object storage; component metadata/versions/subscriptions → Postgres via Ash; compiled ASTs → ETS; rendered HTML → Cachex/Redis (task 08).
