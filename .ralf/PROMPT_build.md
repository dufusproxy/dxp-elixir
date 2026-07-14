{RALFSTOP_EXIT}
0a. Study `{SPECIFICATIONS}` (ignore `{SPECIFICATIONS_IGNORE}`) with up to 500 parallel Sonnet subagents to learn the application specifications. 0b. Study @{IMPLEMENTATION_PLAN} {RALFSTOP_WRITE}. 0c. For reference, the application source code is in `{PROJECT_DIRECTORY}/{SRC_DIR}/*`.
0d. if you are unable to use {MODEL} use Sonnet instead

Your task is to implement functionality per the specifications using parallel subagents. Follow @{IMPLEMENTATION_PLAN} and choose the most important item to address. Before making changes, search the codebase (don't assume not implemented) using Sonnet subagents. You may use up to 500 parallel Sonnet subagents for searches/reads and only 1 Sonnet subagent for build/tests. Use {MODEL} subagents when complex reasoning is needed (debugging, architectural decisions).

After implementing functionality or resolving problems, run the tests for that unit of code that was improved. If functionality is missing then it's your job to add it as per the application specifications. Ultrathink.

When you discover issues, immediately update @{IMPLEMENTATION_PLAN} with your findings using a subagent. When resolved, update and remove the item.

When the tests pass, update @{IMPLEMENTATION_PLAN}, then git add -A then git commit with a message describing the changes. After the commit, git push.
{RALFSTOP_WRITE}

Important: When authoring documentation, capture the why — tests and implementation importance.

Important: Single sources of truth, no migrations/adapters. If tests unrelated to your work fail, resolve them as part of the increment.

As soon as there are no build or test errors create a git tag. If there are no git tags start at 0.0.0 and increment patch by 1 for example 0.0.1 if 0.0.0 does not exist. Continue incrementing patch indefinitely (0.0.2, 0.0.3, ... 0.0.10, 0.0.11, etc.) - only bump minor or major versions when manually instructed.

You may add extra logging if required to debug issues.

Keep @{IMPLEMENTATION_PLAN} current with learnings using a subagent — future work depends on this to avoid duplicating efforts. Update especially after finishing your turn. 9999999999. When you learn something new about how to run the application, update @{AGENTS_FILE} using a subagent but keep it brief. For example if you run commands multiple times before learning the correct command then that file should be updated. 99999999999. For any bugs you notice, resolve them or document them in @{IMPLEMENTATION_PLAN} using a subagent even if it is unrelated to the current piece of work. 999999999999. Implement functionality completely. Placeholders and stubs waste efforts and time redoing the same work. 9999999999999. When @{IMPLEMENTATION_PLAN} becomes large periodically clean out the items that are completed from the file using a subagent. 99999999999999. If you find inconsistencies in the specs/\* then use a {MODEL} subagent with 'ultrathink' requested to update the specs. 999999999999999. IMPORTANT: Keep @{AGENTS_FILE} operational only — status updates and progress notes belong in {IMPLEMENTATION_PLAN}. A bloated {AGENTS_FILE} pollutes every future loop's context.
