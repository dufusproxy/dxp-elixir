# 18 — Infrastructure & Observability

**Priority:** Cross-cutting (local dev in Phase 1; production infra grows with phases) · **Spec:** §7, §7.3, §9.3 · **Depends on:** 01 · **Blocks:** dogfood deployment (Phase 1 exit)

## Goal

The operational substrate: local dev environment, production infrastructure, observability, and the dogfood deployment that closes Phase 1 ("deploy to a single tenant for dogfooding; migrate one real site to it" — spec §8.2).

## Reference architecture (spec §7)

| Layer | Choice |
|---|---|
| Edge | Cloudflare (CDN, WAF, Workers) |
| Web/render | Phoenix + Ash + HEEx |
| Primary store | PostgreSQL 16+ (single DB, Ash multitenancy, RLS defence-in-depth) |
| Cache | Cachex tier-1 + Redis tier-2; ETS for hot ASTs |
| Background work | Oban via AshOban |
| Identity | Keycloak (SSO/SAML) + AshAuthentication |
| DAM | S3-compatible (R2/MinIO) + imgproxy sidecar |
| Observability | OpenTelemetry → Grafana stack (Tempo traces, Loki logs, Prometheus metrics); Sentry for app errors |
| Analytics | PostHog + Plausible |

## Tasks

### Phase 1

- [ ] `docker-compose.yml`: Postgres, Keycloak, MinIO (+ Redis, imgproxy as they land).
- [ ] OpenTelemetry instrumentation in the Phoenix/Ash app from early on; export traces/logs/metrics.
- [ ] Sentry (or equivalent) app-error reporting.
- [ ] Production deploy target (single region is fine) via `infrastructure/terraform/`.
- [ ] Postgres RLS policies as defence-in-depth beneath Ash multitenancy (spec §7.1).
- [ ] Backups + restore runbook (`docs/runbooks/`).
- [ ] **Dogfood**: deploy a single tenant; migrate one real site onto it (Phase 1 exit criterion).

### Ongoing

- [ ] Dashboards for the hot-path targets (spec §7.3): page render P95 <200 ms origin / <50 ms edge; authoring save P95 <300 ms; image derivatives <5 s; search P95 <100 ms; component deploy-to-live <30 s.
- [ ] Cache hit-rate and invalidation fan-out metrics (task 08).
- [ ] Secrets management + encryption at rest (ISO 27001 groundwork from PR #1 — spec §10).
- [ ] Phase 4: helm charts in `infrastructure/k8s/` for self-host customers (task 17).

## Acceptance criteria

- A fresh developer machine reaches a running platform with `docker compose up` + `mix setup`.
- The dogfood tenant serves a real site with observability dashboards showing the hot-path SLOs.
