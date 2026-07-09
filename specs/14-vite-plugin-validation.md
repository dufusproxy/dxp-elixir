# 14 — Vite Plugin Validation Spike

**Priority:** JS track gate (run before investing in task 15; the spec placed this at Phase 0, reprioritized here to precede the JS track since the Elixir core is independent of it) · **Spec:** §8.1, §10 · **Depends on:** 05 (contract), 06 (artefact format) · **Blocks:** 15

## Goal

Prove the riskiest JS-side assumption before investing in the plugin family: a Vite plugin can compile a non-HEEx component (Astro) to a HEEx template string that Phoenix renders correctly, with props, slots, and scoped CSS surviving the round trip.

Because the core platform runs on Phoenix-native components (tasks 05–08), this spike can happen any time before the JS track starts — it no longer blocks platform development, but it still gates any investment in task 15.

## Tasks

- [ ] Select three existing Astro components from the current Squiz workplace pipeline as test subjects.
- [ ] Write a minimal Vite plugin that emits HEEx template strings from them.
- [ ] Render the emitted HEEx through the platform's existing loader (task 06) — not a toy app; the real `Phoenix.LiveView.HTMLEngine` path.
- [ ] Verify props round-trip cleanly (values from Phoenix appear correctly in output).
- [ ] Verify slots round-trip cleanly (slot content renders in the right place).
- [ ] Verify scoped CSS survives compilation and applies.
- [ ] Smoke-test SSR HTML is SEO-complete (fully readable without JS).
- [ ] Smoke-test hydration boots a client counterpart against the server DOM.

## Acceptance / go-no-go

- All three components render correctly through the platform.
- The compiler stays **under ~1000 lines of Node** and output feels clean.
- If not: reconsider the Vite family scope before sinking time in — the Phoenix-native path remains fully functional either way (spec §10: the existing Astro-to-Squiz pipeline already proves the pattern; the Phoenix target is incremental).
