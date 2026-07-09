# 11 — Workflow, Governance & Audit

**Priority:** Core (Phase 1 audit log; Phase 2 workflow/safe-edit) · **Spec:** §2.1, §8.2–8.3 · **Depends on:** 02, 03 · **Blocks:** governance parity with Squiz Matrix

## Goal

The governance baseline that matches Squiz Matrix: per-asset permissions (task 03), approval workflow, audit log, version history, and safe-edit preview — the capabilities that win university/government/council evaluations.

## Tasks

### Phase 1

- [ ] Audit log on every Ash mutation — free via AshPaperTrail (spec §8.2); expose a queryable audit trail (who, what, when, diff).
- [ ] Version history browsing per asset (PaperTrail full diffs).

### Phase 2

- [ ] `Workflow` + `WorkflowRun` Ash resources: configurable approval flows attached to subtrees of the asset DAG.
- [ ] Workflow transitions surfaced through `POST /api/v1/assets/:id/workflow/transitions` (`{transition, comment}`).
- [ ] Tie AshStateMachine transitions to workflow gates: `submit_for_review` → reviewers notified; `approve` → `live`.
- [ ] **Safe-edit**: `start_safe_edit` on a live asset creates an editable state while the live version keeps serving; `commit_safe_edit` atomically swaps. Preview-as-published for safe-edit drafts.
- [ ] Version restore: roll an asset back to a prior PaperTrail version through a normal Ash action (audited like everything else).
- [ ] Notifications for pending reviews (email/webhook via Oban).

## Acceptance criteria

- A live page under safe-edit keeps serving its live content until commit; preview shows the draft exactly as it will publish.
- Every state transition, permission change, and content edit appears in the audit trail with actor + diff.
- Workflow config is itself asset-graph data — versioned and audited.

## Notes

- Squiz-parity governance is a top-level "in scope" item (spec §2.1) and audit/RBAC/encryption are ISO 27001 prerequisites that must exist from the first PR (spec §10).
