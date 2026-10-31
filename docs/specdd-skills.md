# SpecDD skills (Claude Code plugin)

The SpecDD plugin `specdd@specdd` (version 1.0.2) is installed globally for Claude Code at user scope, so it
works in every project. Its skills fire on their own when a request matches; you can also name one directly.

| Skill | What it is for |
|---|---|
| `specdd-adopt` | Set up SpecDD in a project or update its framework files (`specdd init` / `update`) |
| `specdd-orient` | Get oriented in a SpecDD project before working, without editing |
| `specdd-explain` | Explain a spec, a target, a behaviour or the effective spec chain |
| `specdd-author` | Write or revise `.sdd` specs |
| `specdd-task` | Find, add, organise or update `Tasks` entries |
| `specdd-plan` | Plan SpecDD work; clear up unclear scope, authority, risk or verification before editing |
| `specdd-risk` | Classify the risk of a change before work starts |
| `specdd-do` | Implement a code, docs, test, task or spec change under spec authority |
| `specdd-refactor` | Refactor while keeping the specified behaviour |
| `specdd-debug` | Diagnose or fix a bug against the governing spec |
| `specdd-test` | Derive, add, update or assess tests from specs |
| `specdd-trace` | Trace specs to code, tests, docs, changed files and coverage gaps |
| `specdd-review` | Review a change against the governing specs |
| `specdd-docs` | Write or update documentation from specs |
| `specdd-cli` | Use the `specdd` CLI: setup, updates, discovery, inspection, `lint`, `resolve` |

## Retrail-specific behaviour

- Every skill reads `.specdd/bootstrap.project.md`, so Retrail's project rules apply.
- For pure logic in `lib/domain/`, implementation and test derivation go through EXACT (`vaju:tdd-dart`, plugin `vaju`), not
  `specdd-do` or `specdd-test`.
- Widgets, providers and DAOs follow Red-Green-Refactor. Platform code gets its tests alongside the
  implementation.

## Other projects

- In projects without SpecDD the skills stay inactive.
- To adopt SpecDD in one, ask for it (for example "set up SpecDD here"). `specdd-adopt` then runs
  `specdd init`, which keeps an existing `CLAUDE.md`.

## Install or update

```sh
npm install --global specdd                 # CLI (Node 22+)
claude plugin marketplace add specdd/specdd
claude plugin install specdd@specdd --scope user
claude plugin list                          # check it is enabled
```

Newly installed skills show up from the next Claude Code session on.
