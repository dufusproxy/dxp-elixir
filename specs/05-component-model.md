# 05 — Unified Component Model & Contract

**Priority:** Core (Phase 1) · **Spec:** §5.1–5.2, §9.1 · **Depends on:** 02 · **Blocks:** 06, 07, 14, 15

## Goal

Implement the unified component model — the most novel part of the architecture — on the Elixir side. Pages, layouts, and components are **one type** distinguished by role metadata. The component contract (manifest + artefact paths) is the stable public interface; it does not constrain component internals.

For Phase 1 the **Phoenix-native authoring path** (function components / HEEx / LiveView, no compilation step — spec §5.3) is the first-class citizen. The Vite-plugin-transformed path arrives in Phase 2 (tasks 14–15) and targets the exact same contract, which is why the contract must be nailed down here.

## The manifest contract (spec §5.2, §9.1)

Every component ships a `manifest.yaml`:

| Field | Purpose |
|---|---|
| `name` | Globally unique within the component set |
| `version` | Semver; sites pin major versions, minor/patch flow automatically |
| `roles` | Which roles it fills: `page`, `layout`, `component` (multiple permitted) |
| `expects_layout` | Optional: `{matches_role, default}` — declares a wrapper layout |
| `props` | JSON Schema — drives editor UI, runtime validation, IDE autocomplete |
| `slots` | Named slots with accept-types (no scoped slots in v1) |
| `events` | Named events with payload schemas; wired per runtime mode |
| `modes` | Supported runtime modes: `static`, `live_view`, `channels`, `external` |
| `a11y` | Declared accessibility commitments (role, keyboard, ARIA) |
| `artefacts` | Paths: `render_server` (HEEx), `render_client` (JS), `styles` (CSS) |

## Tasks

- [ ] Elixir manifest parser + validator (`Core.Components.Manifest`): parse YAML, validate against the contract, surface clear errors. Parsed once, cached as a struct.
- [ ] JSON Schema validation of `props` blocks (drives prop validation at render time).
- [ ] `Component` and `ComponentVersion` Ash resources: name, semver version, manifest, artefact paths, tenant-scoped.
- [ ] `ComponentSubscription` Ash resource (spec §5.7): sites subscribe by **name + version range** (`article-page: ^2.0.0`), pinnable per asset (`article-page@2.1.3`), with paper trail — version changes auditable, rollback is one update.
- [ ] Semver range resolution: given a subscription and available versions, resolve the effective version.
- [ ] Role/composition rules: a `:page` asset references a component by role; any component may declare `expects_layout`; layouts can have layouts.
- [ ] Starter Phoenix-native component set (`packages/components-core` equivalent, but HEEx-first): a standard layout, an article page, and 2–3 building-block components with manifests.
- [ ] Publish the contract as `docs/component-contract.md` (versioned spec — the published artefact adapter authors will target).

## Acceptance criteria

- A manifest that violates the contract fails validation with a precise error.
- Subscription resolution picks the right version across `^`, `~`, and exact pins, and pin changes are paper-trailed.
- The starter HEEx components register, resolve, and are describable entirely by their manifests.

## Notes

- Styles are an **artefact**, not a contract field — how the author writes CSS is their concern (spec §5.2 changebar).
- Contract versioning policy for the contract *itself* is an open question — defer until the first breaking change (spec §11).
