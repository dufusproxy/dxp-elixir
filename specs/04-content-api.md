# 04 — Content API & Identity

**Priority:** Core (Phase 1, PR #5; AshGraphql in Phase 2) · **Spec:** §9.2, §7 · **Depends on:** 02, 03 · **Blocks:** 12

## Goal

One Ash mutation API through which **all writes from any UI** flow (principle #7). REST via AshJsonApi (OpenAPI emitted automatically), GraphQL via AshGraphql later, identity via Keycloak + AshAuthentication.

## API surface (spec §9.2)

```
POST   /api/v1/assets                          create; body {type, parent_id, link_type, body};
                                               returns created asset + any implied assets
PATCH  /api/v1/assets/:id                      update; body {body, status, metadata};
                                               PaperTrail versions automatically; implications cascade
POST   /api/v1/assets/:id/links                add secondary/notice link to the asset DAG
POST   /api/v1/assets/:id/permissions          grant/revoke; body {principal_id, level}
POST   /api/v1/assets/:id/workflow/transitions move through workflow; body {transition, comment}
DELETE /api/v1/assets/:id                      soft-delete via AshArchival; implied assets cascade
```

## Tasks

- [ ] AshJsonApi endpoint generation from the Asset domain resources.
- [ ] Verify `POST /api/v1/assets` round-trip **with versioning verified** (PR #5 definition).
- [ ] Create responses include any implied assets created alongside.
- [ ] OpenAPI document generated and served.
- [ ] Domain events: all Ash actions emit to a Phoenix PubSub topic; AshOban workers subscribe for indexing, derivatives, cache invalidation, webhooks (spec §9.2).
- [ ] Identity: Keycloak for SSO/SAML; AshAuthentication for service-to-service tokens (spec §7).
- [ ] API authentication + actor resolution feeding the policy layer (task 03).
- [ ] Error envelope and rate-limiting conventions documented in `docs/`.
- [ ] Phase 2: AshGraphql alongside AshJsonApi, backed by the same actions.

## Acceptance criteria

- Create/update/delete through REST produces versions, implied assets, domain events, and policy enforcement — no code path bypasses Ash actions.
- Authoring-save hot path: **P95 < 300 ms** round trip (spec §7.3).

## Notes

- The asset map and content-shaped editor are both projections over this same API; neither may bypass it (spec §4.3).
