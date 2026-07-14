# 12 — Authoring UI (Developer Mode First, Editor Second)

**Priority:** Split — AshAdmin developer mode is Core (Phase 1, near-free); the bespoke editor SPA is Phase 2 (JS track) · **Spec:** §4.3, §7, §8.2–8.3, §11 · **Depends on:** 03, 04 · **Blocks:** non-technical editor adoption

## Goal

Two projections of the same asset graph from day one (the dual-view discipline, spec §4.3): a content-shaped editor that hides assets behind content affordances (default), and an asset-map/developer view (a toggle away, never deferred). Both write through the same Ash mutation API; neither bypasses the asset layer.

Per the Elixir-first reprioritization: **AshAdmin covers the developer-mode requirement in Phase 1 essentially for free**, and is the primary UI until the bespoke editor lands. The Vue 3 SPA moves to the Phase 2 JS track.

## Tasks

### Phase 1 — Elixir-side UI (Core)

- [ ] AshAdmin mounted at `/admin` as the developer-mode view from day one (spec §8.2), behind Keycloak auth.
- [ ] Confirm AshAdmin exposes: asset CRUD, DAG links, permissions, versions, state transitions — enough to author and manage the dogfood site without any JS app.
- [ ] Optional Phase 1 stretch: small LiveView screens in `core_web` for the highest-friction authoring flows (e.g. page edit form generated from the component manifest's props JSON Schema). This also feeds the open question below.

### Phase 2 — Editor UI (JS track)

- [ ] **Resolve open question first (spec §11): Vue 3 SPA vs LiveView for the editor.** Working assumption is Vue 3 + Pinia against the Phoenix API, but the Elixir-first stance strengthens the LiveView case — decide before building the editor view.
- [ ] Editor shell: login via Keycloak, asset tree view (read-only initially — PR #9).
- [ ] Content-shaped editor for the `page` asset type: form generated from the component manifest (props JSON Schema → fields), saving via the AshJsonApi mutation.
- [ ] Progressive disclosure: implied assets surface as `inline_field` or `advanced_panel` per the implication graph (task 02) — editors never see raw assets by default.
- [ ] Dual-view affordances: right-click "Open as asset" (editor → asset map) and "Show in editor" (asset map → editor) (spec §4.3).
- [ ] Phase 2: bespoke asset-map view replacing AshAdmin for developer mode (spec §8.3).

## Acceptance criteria

- Phase 1: a developer can create/edit/publish a page end-to-end through AshAdmin (or LiveView screens) — no JS build required to run the platform.
- Phase 2: a non-technical editor can author a page without ever seeing the asset tree; the asset map stays one toggle away.
- Authoring save round trip P95 < 300 ms (spec §7.3).

## Notes

- "Keeping the data model and replacing the affordance layer is the largest single competitive lever available against Squiz" (spec §4.3) — the editor UX is the wedge, but it rides on the core being right first.
