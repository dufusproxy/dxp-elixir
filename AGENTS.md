# AGENTS.md — working instructions for implementation sessions

## What this project is

An Elixir/Phoenix/Ash multi-tenant DXP (digital experience platform): a Matrix-inspired asset graph, a unified component model (pages, layouts, and components are one type with role metadata), server-rendered SEO-complete HTML, and a progressive-disclosure authoring UX.

- **Source of truth:** `specs/dxp-plan-and-spec-v2.pdf` (the full architectural spec).
- **Plan & milestone order:** `specs/00-overview.md` — index of all work packages (`specs/NN-*.md`), the milestone sequence, and the dependency graph. The overview is canonical; if anything in this file disagrees with it, the overview wins.
- **Live progress:** `specs/STATUS.md` — what's done, what's in progress, what's next.

## The "continue implementation" protocol

When the user asks you to continue implementation (in any phrasing), follow this loop:

1. **Orient.** Read `specs/STATUS.md`, then `specs/00-overview.md`, then `git log --oneline -20`. If STATUS.md disagrees with what the code/git history shows, trust the code and fix STATUS.md first (in the next commit).
2. **Pick.** If STATUS.md shows a milestone **in progress** (or the log shows a `wip:` commit), resume it. Otherwise take the next milestone from the sequence in `specs/00-overview.md` (the reordered "first ten pull requests" list, then the remaining Phase 2 work packages in dependency order).
3. **Implement.** Read the relevant `specs/NN-*.md` work package(s) fully before writing code. The package's acceptance criteria define done.
4. **Verify.** Before a milestone counts as complete: compiles without warnings, `mix format --check-formatted` passes, credo is clean, the full test suite passes, and new behaviour has tests. Never mark a milestone done on a broken build.
5. **Record.** In the same commit as the work: tick the completed `- [ ]` checkboxes in the relevant `specs/NN-*.md` file(s) and update `specs/STATUS.md`.
6. **Commit & push** to the branch this session designates. Never force-push. Never push to `main`.
7. **Continue or stop** per the batch instruction below.

## How many milestones to do (the batch contract)

The user controls batch size in their prompt. Interpret it as:

| User says (any similar phrasing) | You do |
|---|---|
| "implement the next item" / "continue implementation" (no count) | **One** milestone, then stop and report. |
| "implement the next 3 items" | Three milestones, reporting briefly after each commit, full report at the end. |
| "implement items until further notice" / "continue until blocked" | Loop milestones until you hit a blocker, a decision only the user can make, or the user interrupts. Commit and push after **each** milestone so no work is stranded. |
| "complete current task" / "finish up" (typically after interrupting) | Finish only the in-progress milestone — implement its remaining checklist items, verify, commit, push, report — then stop. Do not start the next one. |
| "stop" / "pause" | Get to the nearest safe state (see interruption handling), commit as `wip:` if incomplete, push, report where things stand. |

Default when ambiguous: **one milestone**. Never start a milestone the user's instruction doesn't cover.

## Low-context / interruption handling

- Prefer finishing the current milestone. If it clearly won't fit in the remaining context, stop at a coherent sub-step instead of half-applying a change.
- When stopping mid-milestone: commit as `wip: <milestone> — <exact stopping point>`, push, and write a precise resume note in `specs/STATUS.md`: what's done, the next concrete step, and anything surprising the next session should watch out for.
- A fresh session that finds a `wip:` commit or an "in progress" STATUS entry resumes it rather than starting a new milestone. `wip:` commits may have failing tests; a completed-milestone commit may not.

## specs/STATUS.md format

Keep it short — it's an orientation card, not a log:

```markdown
# Implementation status

**Current milestone:** M<N> — <name> (`specs/NN-*.md`) — not started | in progress | done
**Last completed:** M<N> — <name> — <commit sha>
**Next up:** M<N> — <name>

## Blockers / decisions needed
- (none)

## Notes for next session
- <resume notes, gotchas, partial-work pointers>
```

## Engineering conventions

- Phoenix umbrella app lives in `apps/core` (`Core` = Ash domain, `CoreWeb` = web). Follow the repo layout in `specs/01-project-scaffolding.md`.
- **All writes go through Ash actions.** Never bypass to raw Ecto for domain data.
- **Every resource is multitenant** (Ash `:attribute` strategy on `tenant_id`) with tests proving no cross-tenant access.
- **Policies on every resource**; authorization is never skipped in production code paths.
- Versioning via AshPaperTrail — never hand-roll version tables.
- Secrets via runtime config/env only; nothing secret in the repo.
- Technology choices follow the reference architecture in spec §7 (see `specs/18-infrastructure-observability.md`). Don't introduce new runtimes/dependencies outside it without asking.
- Local services (Postgres, Keycloak, MinIO, …) come from `infrastructure/docker-compose.yml`.

## Reporting format

When you stop, report:

1. **Completed:** milestone(s) + commit sha(s), one line each on what they delivered.
2. **Verification:** test/format/credo results (actual output summary, not "should pass").
3. **Next up:** the next milestone in sequence.
4. **Blockers / decisions needed:** anything ambiguous in the spec, or choices the user must make (see the open-questions list in `specs/00-overview.md`).

## Boundaries

- Don't create pull requests unless asked (PR #1 already tracks the working branch).
- Don't reorder or rescope milestones without asking — flag sequencing problems in your report instead.
- On architecturally significant ambiguity in the spec, ask (or report) rather than guess; for small gaps, decide sensibly and note the decision in STATUS.md.
