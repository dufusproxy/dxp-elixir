# 01 — Project Scaffolding

**Priority:** Core (Phase 1) · **Spec:** §7, §9.3, §9.4 (PR #1) · **Depends on:** nothing · **Blocks:** everything

## Goal

Create an Ash project with PostgreSQL persistence. This is the foundation - Ash is the primary framework. Web layer (Phoenix/ash_phoenix) can be added later when needed.

## Tasks

- [ ] Create Ash project with `mix igniter.new core --install ash`.
- [ ] Add `ash_postgres` and configure against PostgreSQL 16+.
- [ ] Configure Ash `:attribute` multitenancy (`tenant_id`) from the first resource - no single-tenant assumptions (spec §7.1).
- [ ] Set up local dev infrastructure: `docker-compose.yml` with Postgres.
- [ ] CI: compile with warnings-as-errors, `mix format --check-formatted`, credo, test run.
- [ ] Verify basic Ash resource works in `iex -S mix`.

## Acceptance criteria

- `docker compose up` + `mix deps.get` + `iex -S mix` allows creating/querying an Ash resource backed by Postgres.
- All resources are tenant-scoped at the framework level from the first commit.
- Build passes with zero warnings.

## Notes

- Web layer (ash_phoenix) and admin UI (AshAdmin) come in later milestones when we actually need HTTP endpoints.
- Keep secrets in runtime config only, never in the repo.
