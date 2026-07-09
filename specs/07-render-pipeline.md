# 07 — Render Pipeline, Layout Composition & SSR

**Priority:** Core (Phase 1, PRs #8, #10) · **Spec:** §5.4–5.6 · **Depends on:** 02, 05, 06 · **Blocks:** 08

## Goal

The Phoenix render path: resolve a page asset to its component + version, compose layouts recursively, render **complete, SEO-perfect HTML** with props emitted alongside as the hydration input. Server HTML is the truth; hydration (Phase 2, task 15) attaches behaviour to the existing DOM — it never re-renders.

## Tasks

### Render path

- [ ] Route resolution: URL asset → page asset → component reference (by role) → subscription/pin → ComponentVersion.
- [ ] Load compiled HEEx AST from ETS (via task 06 loader), render with props resolved from asset content via Ash.
- [ ] Props validated against the manifest's JSON Schema at render time.
- [ ] Emit props alongside the HTML as a JSON payload (`<script type="application/json" data-props-for="...">` or data attributes — whichever is cleaner per component shape) so a client component can later boot with the same props (spec §5.5).
- [ ] Mark hydratable components with `data-component` / `data-component-id` attributes (the Phase 2 hydration runtime queries these).
- [ ] Link component `styles.css` from the rendered page.

### Layout composition & cycle prevention (spec §5.6)

- [ ] Recursive slot-filling composition: render layout, render wrapped component into the layout's default slot, recurse. Uniform for page-in-site-shell, field-in-field-group, comment-in-frame.
- [ ] `expects_layout` resolution from manifests (role/contract matching, defaults).
- [ ] Render-time depth limit: maintain a stack of components being rendered; abort with a structured error if a component is already on the stack (backstop to publish-time static analysis in task 06).

### Runtime modes (spec §5.4)

- [ ] Phase 1: **static SSR** mode only (render once, cache; page-reload updates) — the mode for marketing pages, articles, listings.
- [ ] Mode declaration honoured from manifests (`modes:`); instance-level mode selection modelled on the page asset now, even though only `static` executes in Phase 1.
- [ ] Phase 3 (task 16): `live_view`, `channels`, `external` modes.

## Acceptance criteria

- First end-to-end page render from authored content (PR #8): page asset → HEEx from object storage → ETS AST → HTML with props payload.
- Rendered HTML is complete and indexable with JS disabled — no placeholders.
- A cyclic layout chain that escapes static analysis is caught by the depth limit with a structured error.
- Public page render hot path (with task 08): **P95 < 200 ms at origin on cache miss** (spec §7.3).

## Notes

- Four runtime modes exist per component instance; the same component can be static on the homepage and LiveView on a dashboard (spec §5.4). Only static ships in Phase 1.
- This is where "server emits complete final HTML, props are the input, hydration attaches" (spec §5.5) is enforced — the design that eliminates React-style hydration-mismatch bugs.
