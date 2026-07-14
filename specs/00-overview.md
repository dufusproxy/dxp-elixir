# DXP — Task Breakdown Overview

Source of truth: [`dxp-plan-and-spec-v2.pdf`](./dxp-plan-and-spec-v2.pdf) — "Building a Modern DXP, Plan and architectural specification — v2" (4 May 2026).

An Elixir/Phoenix/Ash-based multi-tenant DXP with a Matrix-inspired asset graph, a unified component model (pages, layouts, and components are one type with role metadata), a framework-agnostic Vite plugin family for authoring, and a progressive-disclosure authoring UX.

## Prioritization note (differs from the spec's ordering)

This breakdown puts the **Elixir/Ash core first**. The spec's §5.3 makes Phoenix-native components (function components / HEEx / LiveView, no compilation step) a first-class authoring path, so the entire core platform — asset graph, permissions, API, component runtime, render pipeline, caching, governance — can be built and dogfooded with Phoenix-native components and AshAdmin/LiveView as the UI. The JS track (Vite plugin family, client hydration runtime, Vue authoring SPA) is deferred to Phase 2 and layers onto the already-fixed component contract and artefact format without platform changes. The spec's Phase 0 Vite spike (its §8.1) accordingly becomes the gate for the JS track (task 14) rather than a gate for the whole project.

## Work packages

### Track A — Elixir core (Phase 1: minimum viable platform)

| # | Task file | Spec sections |
|---|-----------|---------------|
| 01 | [Project scaffolding & repo layout](./01-project-scaffolding.md) | §7, §9.3 |
| 02 | [Asset model (Ash resources)](./02-asset-model.md) | §4 |
| 03 | [Permissions & policies](./03-permissions.md) | §4.1, §8.3 |
| 04 | [Content API & identity](./04-content-api.md) | §9.2, §7 |
| 05 | [Unified component model & contract](./05-component-model.md) | §5.1–5.2, §9.1 |
| 06 | [Component runtime loading](./06-component-runtime-loading.md) | §6 |
| 07 | [Render pipeline, layouts & SSR](./07-render-pipeline.md) | §5.4–5.6 |
| 08 | [Render cache & invalidation](./08-caching.md) | §6.3–6.4, §7.3 |
| 09 | [DAM v1](./09-dam.md) | §7, §8.2 |
| 11 | [Workflow, governance & audit](./11-workflow-governance.md) — audit-log part | §8.2 |
| 12 | [Authoring UI](./12-authoring-ui.md) — AshAdmin developer mode part | §4.3, §8.2 |
| 18 | [Infrastructure & observability](./18-infrastructure-observability.md) — local dev + dogfood | §7 |

**Phase 1 exit:** the smallest end-to-end DXP rendering real pages from authored content (spec §9.4), deployed to a dogfood tenant with one real site.

### Track A continued — Phase 2 core (DXP-shaped)

| # | Task file | Spec sections |
|---|-----------|---------------|
| 03 | Permissions — full inheritance hardening + cache | §8.3 |
| 10 | [Search (Postgres FTS)](./10-search.md) | §7.2, §8.3 |
| 11 | Workflow, safe-edit, approvals | §8.3 |
| 13 | [Multi-site, localization & forms](./13-multisite-localization-forms.md) | §8.3 |
| 04 | AshGraphql alongside AshJsonApi | §8.3 |

### Track B — JS/authoring (Phase 2, after core is dogfooding)

| # | Task file | Spec sections |
|---|-----------|---------------|
| 14 | [Vite plugin validation spike](./14-vite-plugin-validation.md) — go/no-go gate for the track | §8.1 |
| 15 | [Vite plugin family & hydration runtime](./15-vite-plugin-family.md) | §5.3, §5.5 |
| 12 | Authoring UI — bespoke editor (Vue 3 vs LiveView decision first, spec §11) | §8.2–8.3 |

### Later phases

| # | Task file | Phase |
|---|-----------|-------|
| 16 | [Phase 3 — competitive](./16-phase3-competitive.md) (runtime modes 2–4, n8n, RudderStack, A/B, RAG search, Meilisearch, public contract) | 3 |
| 17 | [Phase 4 — differentiation](./17-phase4-differentiation.md) (agentic authoring, content intelligence, ISO 27001, registry/SDK, self-host) | 4 |

## Dependency graph (core track)

```
01 scaffolding
 └─ 02 asset model ── 03 permissions ── 04 content API ── 12 authoring UI
     │                                                     (AshAdmin first)
     └─ 05 component model ── 06 runtime loading ── 07 render pipeline ── 08 cache
                                   │                                        │
                                   └── 14 vite spike ── 15 vite family      └─ dogfood
 09 DAM, 10 search, 11 workflow, 13 multisite, 18 infra — hang off 02–04
```

## The first ten pull requests (spec §9.4, reordered Ash-first)

1. Ash project + AshPostgres; tenant-scoped resources from first commit → *01*
2. Asset resource (PaperTrail/StateMachine/Archival/multitenancy) → *02*
3. AssetLink + DAG traversal calculations → *02*
4. Permission resource + policy module + ETS cache → *03*
5. AshJsonApi generation; POST /api/v1/assets round-trip with versioning → *04*
6. Component + ComponentVersion resources; artefact upload to MinIO via CLI → *06* *(spec's PR 7)*
7. Add ash_phoenix; render path: HEEx from object storage → ETS AST → render with props → *07* *(spec's PR 8)*
8. Render-and-cache: Cachex tier-1, AshOban invalidation; visible static site → *08* *(spec's PR 10)*
9. Vite plugin core + Astro adapter; three components compile to HEEx → *14/15* *(spec's PR 6, deferred to JS track)*
10. Editor shell (Vue or LiveView per §11 decision); content-shaped page editor → *12* *(spec's PR 9, deferred)*

## Architectural principles (spec §3, priority order — higher wins on conflict)

1. Progressive disclosure of complexity — editors see content, not assets.
2. One source, many runtimes — the component contract is the stable public interface.
3. Unified component model — pages/layouts/components are one type with roles.
4. Implicit creation of implied assets.
5. Server-rendered, SEO-complete by default; hydration attaches, never re-renders.
6. Standards at the contract surface (DTCG, JSON Schema, OpenAPI, WCAG 2.2), freedom inside.
7. Asset graph as single source of truth — all writes through one Ash mutation API.
8. Multi-tenant from day one (Ash :attribute multitenancy; RLS as defence-in-depth).
9. Single-runtime preferred — no JVM; Elixir-native or single-binary sidecars.
10. Bounded surface area — build seven capabilities exceptionally well, integrate the rest.

## Hot-path targets (spec §7.3)

| Path | Target |
|---|---|
| Public page render | P95 < 200 ms origin on miss; < 50 ms edge on hit |
| Authoring save | P95 < 300 ms round trip |
| Image upload | original immediate; derivatives < 5 s |
| Search query | P95 < 100 ms |
| Component publish | deploy-to-live < 30 s |

## Out of scope (spec §2.2–2.3)

E-commerce engine, marketing automation, native mobile authoring, full CDP, translation memory, AEM feature parity, replacing Funnelback's ranking engine, privileging one authoring framework, becoming the full martech stack.

## Open questions to resolve before the relevant phase (spec §11)

- Authoring UI framework — Vue 3 vs LiveView (before the bespoke editor; the Elixir-first stance strengthens LiveView's case)
- Custom-element interop for client-rendered components (before Phase 3)
- Pricing model (before second customer)
- Self-host distribution model (before Phase 4)
- Component contract versioning policy (defer until first breaking change)
- Squiz Matrix migration tooling (revisit when the first Squiz customer asks)
- Scoped slots in contract v2 (revisit on real need)
- Project naming
