# 01 — Project Scaffolding & Repo Layout

**Priority:** Core (Phase 1) · **Spec:** §7, §9.3, §9.4 (PR #1) · **Depends on:** nothing · **Blocks:** everything

## Goal

Stand up the monorepo skeleton and the Phoenix umbrella app with Ash wired in, matching the repository layout in spec §9.3, so every subsequent work package has a home. The Elixir core is the product; JS packages get placeholder directories only.

## Target repo layout (spec §9.3)

```
/
|-- apps/
|   |-- core/                  # Phoenix umbrella app, Ash domain  ← THE FOCUS
|   |   |-- lib/core/          # Ash resources — assets, components, workflows
|   |   |-- lib/core_web/      # HTTP endpoints, LiveView admin screens
|   |   `-- priv/repo/migrations/
|   |-- authoring/             # Vue 3 SPA — the editor UI          (Phase 2)
|   `-- component-runtime/     # client-side hydration runtime      (Phase 2)
|-- packages/                  # JS workspace                       (Phase 2)
|   |-- component-contract/    # manifest spec, JSON Schemas, types
|   |-- vite-plugin-core/      # plugin family core, adapter contract
|   |-- vite-plugin-astro/     # Astro adapter
|   |-- vite-plugin-vue/       # Vue adapter
|   |-- adapter-astro-squiz/   # existing Squiz target — kept for migration
|   |-- design-tokens/         # W3C DTCG tokens, shared across targets
|   `-- components-core/       # the starter component set
|-- infrastructure/
|   |-- docker-compose.yml     # local dev — postgres, keycloak, minio
|   |-- terraform/             # production infra
|   `-- k8s/                   # helm charts for self-host customers
`-- docs/
    |-- component-contract.md  # the published spec
    |-- architecture/
    `-- runbooks/
```

## Tasks

- [ ] Create the monorepo directory structure above (JS dirs as stubs with READMEs).
- [ ] Generate the Phoenix umbrella app in `apps/core` with `Core` (Ash domain) and `CoreWeb` apps.
- [ ] Add Ash + AshPostgres; configure `Core.Repo` against PostgreSQL 16+.
- [ ] Configure Ash `:attribute` multitenancy (`tenant_id`) from the very first migration (spec §7.1 — single-tenant assumptions are technical debt the moment the second customer signs).
- [ ] Add a hello-world HTTP endpoint.
- [ ] Mount AshAdmin at `/admin`.
- [ ] `infrastructure/docker-compose.yml` for local dev: Postgres, Keycloak, MinIO.
- [ ] CI: compile with warnings-as-errors, `mix format --check-formatted`, credo, test run.
- [ ] Baseline `docs/architecture/` page describing the umbrella layout.

## Acceptance criteria

- `docker compose up` + `mix setup` + `mix phx.server` yields a working hello-world endpoint and AshAdmin at `/admin` (PR #1 definition, spec §9.4).
- All queries are tenant-scoped at the framework level from the first commit.

## Notes

- ISO 27001 groundwork (audit log, RBAC, encryption at rest, secrets management) "all need to be there from the first PR" (spec §10) — keep secrets in runtime config, never in the repo.
