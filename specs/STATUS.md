# Implementation status

**Current milestone:** M1 — Project scaffolding & repo layout (`specs/01-project-scaffolding.md`) — in progress
**Last completed:** — (specs only; no implementation yet)
**Next up:** M2 — Asset resource (`specs/02-asset-model.md`), then M3 — AssetLink + DAG traversal

## Blockers / decisions needed
- Hex was unreachable in the previous session: `repo.hex.pm` / `builds.hex.pm` / `diffs.hex.pm` returned 403 from the egress proxy. Confirmed experimentally that allowlist changes made while a session is running never reach that session — the policy is snapshotted at container start. The allowlist now contains `hex.pm`, `repo.hex.pm`, `builds.hex.pm`, `diffs.hex.pm`, **and `*.hex.pm`**, so a fresh session should have them. Verify with `curl -sS -o /dev/null -w "%{http_code}" https://repo.hex.pm/` (expect 200) before running `mix deps.get`; if it still 403s, report the blocked host to the user rather than working around it.

## Notes for next session
- First time here? Read `specs/00-overview.md` for the milestone sequence and dependency graph, and `AGENTS.md` (repo root) for the working protocol.
- M1 progress so far: monorepo directory skeleton only — placeholder READMEs for the Phase 2 JS dirs (`apps/authoring`, `apps/component-runtime`, `packages/*`) and `infrastructure/{terraform,k8s}`, `docs/runbooks`. **No Elixir code yet.**
- Next concrete step: generate the Phoenix umbrella in `apps/core` (Core = Ash domain, CoreWeb = web), wire Ash + AshPostgres, then the rest of the M1 checklist (docker-compose, hello-world endpoint, AshAdmin at `/admin`, CI).
- Environment notes: Elixir 1.17.3 / OTP 25 preinstalled; Postgres 16 already running locally on :5432 (owner `postgres`) — usable for dev/test without docker-compose. Locale is POSIX; set `ELIXIR_ERL_OPTIONS="+fnu"` (or a UTF-8 locale) to silence the latin1 warning.
