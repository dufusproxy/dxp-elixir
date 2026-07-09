# 02 — Asset Model (Ash Resources)

**Priority:** Core (Phase 1, PRs #2–3) · **Spec:** §4 · **Depends on:** 01 · **Blocks:** 03, 04, 07, 11, 12

## Goal

Implement the asset graph — the platform's single source of truth and its biggest inheritance from MySource/Squiz Matrix. A directed acyclic graph of typed assets: every page, image, user, group, component instance, redirect, form-submission store, metadata schema, and workflow is an asset, expressed as Ash resources on Postgres.

## Tasks

### Core.Assets.Asset resource (PR #2)

- [ ] `Asset` resource with extensions: `AshPaperTrail.Resource` (versioning, `change_tracking_mode :full_diff`), `AshStateMachine`, `AshArchival.Resource` (soft-delete/trash), `AshOban` (background jobs hook).
- [ ] Attributes: `uuid_primary_key :id`, `:type` (atom, required), `:role` (atom — `:page`/`:layout`/`:component` for components), timestamps.
- [ ] Multitenancy: `:attribute` strategy on `tenant_id`.
- [ ] State machine: `draft → review → live → safe_edit → archived` with transitions `submit_for_review`, `approve`, `start_safe_edit`, `commit_safe_edit`, `archive` (from `[:live, :draft]`).
- [ ] Actions: `defaults [:read]`, `create :create`, `update :update`, `destroy :archive` (primary, soft via AshArchival).
- [ ] CRUD works end-to-end through AshAdmin.

### Companion resources (PRs #2–3)

- [ ] `AssetLink` — the DAG edges (`parent_id`/`child_id`), link types: primary, secondary, notice. One asset can have many parents.
- [ ] DAG traversal helpers as Ash calculations: ancestors, descendants, paths.
- [ ] DAG integrity: cycle prevention on link creation.
- [ ] `MetadataSchema` and `MetadataValue` — typed metadata.
- [ ] `Workflow` and `WorkflowRun` — approval flows (fleshed out in task 11).
- [ ] `Permission` — principal-level grants (fleshed out in task 03).

### Implication graph (spec §4.2)

- [ ] Build `Core.Implications` — a small Spark DSL extension on Ash resources declaring which assets an asset type implies.
- [ ] Per implication: `default` (how to create it), `surfaced_as` (`:inline_field` / `:advanced_panel`), `on_delete` (`:cascade` / `:convert_to_redirect` / …).
- [ ] `Core.Content.Page` declares `implies :url` (default computed from slug; deleting converts to redirect) and `implies :metadata_record` (empty for schema; cascade on delete).
- [ ] Implied assets are created automatically with sensible defaults and surfaced only when the editor wants to deviate (principle #4).

## Acceptance criteria

- Creating a Page via an Ash action implicitly creates its URL and metadata record.
- Every mutation produces an AshPaperTrail version with full diff.
- Soft-deleted assets land in the trash and are restorable.
- No query can cross tenants (verified by test).

## Notes

- Versioning is AshPaperTrail — do **not** hand-roll an `asset_versions` table (spec §4.1).
- The implication graph drives editor UI generation, asset bootstrapping, and cascade behaviour on move/delete. It is the mechanism that kills Matrix's "create a URL asset, then create a page, then link them" friction (spec §4.3).
