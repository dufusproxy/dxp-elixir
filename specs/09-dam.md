# 09 — DAM (Digital Asset Management) v1

**Priority:** Core (Phase 1) · **Spec:** §7, §7.3, §8.2 · **Depends on:** 01, 02, 04 · **Blocks:** editor image workflows (12)

## Goal

Minimal, solid media handling: direct-to-S3 uploads from the browser, image metadata as Ash resources in the asset graph, derivatives via imgproxy.

## Tasks

- [ ] Signed-URL issuance endpoint: browser uploads directly to S3/MinIO, bypassing the app server.
- [ ] Image asset type in the asset graph; metadata (dimensions, mime, alt text, focal point) as Ash resources alongside content (spec §6.4).
- [ ] Oban derivative job on upload completion (probe dimensions, generate any precomputed variants).
- [ ] imgproxy sidecar for on-the-fly resize at delivery, fronted by CDN.
- [ ] Upload lifecycle events into the domain-event stream (indexing, cache invalidation).
- [ ] Permissions: image assets inherit DAG permissions like any other asset.

## Acceptance criteria

- Image upload hot path (spec §7.3): original visible to the editor **immediately**; derivatives ready **within 5 seconds**.
- Binaries live in object storage only; Postgres holds metadata only.

## Notes

- imgproxy + object storage keeps the single-runtime principle: no image processing inside the BEAM, one small sidecar binary.
