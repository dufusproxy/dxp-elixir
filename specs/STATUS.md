# Implementation status

**Current milestone:** M1 — Project scaffolding (`specs/01-project-scaffolding.md`) — done
**Last completed:** M1 — Ash project + ash_postgres, docker-compose for Postgres
**Next up:** M2 — Asset resource (`specs/02-asset-model.md`), then M3 — AssetLink + DAG traversal

## M1 completed
- Ash project created in `core/` directory
- ash_postgres added and configured
- docker-compose.yml for local Postgres
- Basic Ash domain structure (`Core.Domain`, `Core.Repo`)
- Verified Ash works (create/read resources in iex)

## Notes
- Web layer (ash_phoenix) will be added at PR #7 when we need render pipeline
- AshAdmin will be added when we have resources to manage
