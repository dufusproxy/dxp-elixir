# 15 — Vite Plugin Family & Client Hydration Runtime

**Priority:** Phase 2 (JS track — after the Elixir core is dogfooding) · **Spec:** §5.3, §5.5, §8.2–8.3 · **Depends on:** 05, 06, 07, 14 (go decision) · **Blocks:** non-Elixir component authoring

## Goal

The framework-agnostic authoring on-ramp: a Vite plugin family that transforms SSR output from Astro, Vue, and other compatible frameworks into the Phoenix component artefact format. No framework is privileged at the contract level; the platform team maintains the plugin core and launch adapters (Astro, Vue).

Everything here targets the contract and artefact format already fixed by tasks 05–06 — the Elixir platform needs no changes to accept Vite-compiled components.

## Tasks

### Plugin family (`packages/`)

- [ ] `vite-plugin-core`: the adapter contract — pre-render the component, extract the manifest, bundle client JS + CSS, emit `render_server.heex` / `render_client.js` / `styles.css` / `manifest.yaml`.
- [ ] `vite-plugin-astro`: Astro adapter (first-party, launch).
- [ ] `vite-plugin-vue`: Vue adapter (first-party, Phase 2 per spec §8.3).
- [ ] `component-contract` package: JSON Schemas + types for the manifest, shared by all adapters, generated from/validated against `docs/component-contract.md` (task 05).
- [ ] `design-tokens` package: W3C DTCG tokens shared across targets.
- [ ] Keep `adapter-astro-squiz` in-tree for migration continuity.
- [ ] Three real components from the existing Squiz pipeline compile and render in production via the platform (PR #6 definition, spec §9.4).

### Client hydration runtime (`apps/component-runtime`, spec §5.5)

- [ ] Hydration spine (~150 lines): registry of `name → loader`; `hydrateAll()` finds `[data-component]` markers, reads the adjacent props JSON, lazy-loads the matching client bundle, calls `Component.hydrate(el, props)` — attach behaviour to existing DOM, never re-render.
- [ ] Production polish (~1500–3000 lines total): IntersectionObserver lazy loading below the fold, requestIdleCallback for non-critical components, shared-runtime deduplication (one framework runtime copy per page).
- [ ] Hydration correctness tests: client boot with server props produces the identical DOM (attach, not re-render).

## Acceptance criteria

- An Astro component authored by someone who knows no Elixir deploys via `dxp deploy` and renders SSR-complete with working hydration.
- The same component passes the contract validation and cycle analysis like any Phoenix-native component.
- Adapter authors outside the team can target the published contract (docs complete).

## Notes

- Community adapters (Svelte, Lit) are welcome but not guaranteed to track upstream (spec §5.3); a public plugin SDK is Phase 4 (task 17).
