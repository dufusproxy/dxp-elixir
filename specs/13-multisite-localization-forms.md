# 13 — Multi-site, Localization & Forms

**Priority:** Phase 2 · **Spec:** §8.3 · **Depends on:** 02, 04, 05, 07 · **Blocks:** DXP-shaped completeness

## Goal

The Phase 2 features that turn the minimum viable platform into something DXP-shaped: many sites per tenant, per-locale content, and a forms engine — all expressed through the existing asset graph and component model rather than as new subsystems.

## Tasks

### Multi-site (spec §8.3)

- [ ] Site as an asset-graph concept: multiple sites under one tenant.
- [ ] Per-site design system and component library (per-site `ComponentSubscription` sets + design tokens).
- [ ] Per-site domains/URL roots resolved in the render pipeline.

### Localization (spec §8.3)

- [ ] Per-locale content variants on Ash resources.
- [ ] Fallback chains (e.g. `de-AT → de → en`).
- [ ] Locale-aware URLs feeding route resolution and the render cache key (locale is already part of the cache key, task 08).
- [ ] Hooks for external translation tooling — translation memory/CAT is explicitly out of scope (spec §2.2).

### Forms engine v1 (spec §8.3)

- [ ] A form is just a component with role `:form` — no separate forms subsystem.
- [ ] Form submissions land in a submission-store asset; submissions are an Ash resource (tenant-scoped, permission-guarded, audited).
- [ ] Server-side validation from the form component's props/JSON Schema.
- [ ] Submission notifications/exports via Oban + domain events.

## Acceptance criteria

- Two sites under one tenant serve different design systems from the same platform instance.
- A localized page falls back correctly and caches per locale.
- A form component renders statically (SEO-complete), accepts submissions through the mutation API, and its submissions appear as queryable Ash resources.
