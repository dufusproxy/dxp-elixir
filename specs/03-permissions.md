# 03 — Permissions & Policies

**Priority:** Core (Phase 1 baseline — PR #4; full inheritance hardening in Phase 2) · **Spec:** §4.1, §8.3, §10 · **Depends on:** 02 · **Blocks:** 04, 11, 12

## Goal

Matrix-style Read/Write/Admin permission model, granted per asset to principals (users/groups), inherited down the asset DAG, enforced via Ash policies, with an ETS-backed cache to keep authorization off the render hot path.

## Tasks

- [ ] `Core.Assets.Permission` resource: `{asset_id, principal_id, level}` where level ∈ `:read | :write | :admin`.
- [ ] `Core.Policies.HasAssetPermission` Ash policy check module resolving the effective level for an actor on an asset **via DAG inheritance** (walk the primary-parent chain; nearest explicit grant wins).
- [ ] Wire policies onto `Asset` (spec §4.1):
  - `action_type(:read)` → requires `:read`
  - `action_type([:create, :update])` → requires `:write`
  - `action_type(:destroy)` → requires `:admin`
- [ ] ETS-backed permission cache: resolved `{actor, asset} → level`; invalidated on Permission/AssetLink mutations (Ash change hooks → Phoenix PubSub → cache bust).
- [ ] Property/regression tests: inheritance down deep trees, multiple parents (primary link governs inheritance), revocation propagation, cache coherence after grant/revoke/move.
- [ ] Load test: warm-cache authorization adds negligible latency to renders.

## Acceptance criteria

- PR #4 (spec §9.4): Permission resource + policy module resolving Read/Write/Admin via inheritance + ETS cache, green in CI.
- Multitenancy applies to Permission — no cross-tenant permission reads.

## Notes

- Postgres RLS remains a defence-in-depth layer beneath Ash multitenancy (spec §7.1); primary enforcement is Ash.
- RBAC comes "free via Ash policies" and is part of the ISO 27001 groundwork (spec §10).
