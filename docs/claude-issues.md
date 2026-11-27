# Claude issues: the full workflow

Issues that the owner labels `claude` are worked by Claude Code in GitHub Actions. Each one ends as
a pull request or as a question in the issue. Nothing reaches `main` without the owner's approval.

Workflow file: `.github/workflows/claude-issues.yml`. It replaces an earlier cloud routine (paused,
not deleted), which had no Flutter and pushed with the owner's admin token.

## Day to day

1. Write the issue yourself. Describe the task fully. Do not paste text from other people, web
   pages or logs into it; paraphrase instead, because owner text is trusted.
2. Set the label `claude`.
3. Wait. Every 3 hours (minute 52, UTC) the workflow takes up to 3 issues, oldest first. To start at
   once: Actions → "Claude issues" → "Run workflow" on `main`, or `gh workflow run claude-issues.yml`.
4. Look at the result:
   - a **PR** (draft when a check failed) with a summary, test result and review comment;
   - or a **question** in the issue.
5. Review the PR, approve it and merge. CI (`dart-check`) must be green.

Answering a question: reply in the issue, then remove `claude-rueckfrage`. The next run picks the
issue up again. After a failure: read the linked run, delete a left-over branch `claude/issue-<N>`
if there is one, remove `claude-fehler`.

## Labels

| Label | Set by | Meaning |
|---|---|---|
| `claude` | owner | hand the issue to Claude |
| `claude-laeuft` | workflow | a run works on it now |
| `claude-pr` | workflow | PR is open; `claude` is removed |
| `claude-rueckfrage` | workflow | question in a comment; `claude` stays |
| `claude-fehler` | workflow | the run ended without a PR or a question (link in a comment) |

Filters: `gh issue list --label claude-rueckfrage`, `gh pr list --search "head:claude/"`.

## What a run does

| Job | Agent | Token | Does |
|---|---|---|---|
| `pick` | no | issues: write | picks up to 3 issues the owner wrote and labelled, sets `claude-laeuft` (only on `main`) |
| `implement` | Sonnet (Opus subagent for big tasks) | read-only | works one issue after the other on a local branch, runs format, analyze, test, `specdd lint`, hands over patches, PR title and text, or a question |
| `publish` | no | contents, PRs, issues: write | checks the hand-over, refuses changes under `.github/`, pushes `claude/issue-<N>`, opens the PR (draft if not green), sets labels or posts the question |
| `review` | Opus | read-only | reviews every change that is not docs-only (decided from the changed files, not by the agent) and fixes critical and major findings |
| `publish-fix` | no | contents, PRs: write | pushes the review commits (fast-forward only), posts the review comment |
| `finish` | no | issues, actions: write | removes `claude-laeuft`, sets `claude-fehler` where nothing came out, starts `ci.yml` on each open PR branch |

CodeRabbit does not review these PRs: they are opened by the Actions bot, and on the free plan
CodeRabbit skips bot PRs ("Bot user detected"), also when the owner asks with `@coderabbitai review`
and after a new commit. Opus is the only reviewer of the workflow. CodeRabbit stays in use for the
owner's own PRs and the local CLI.

## Safety model

Enforced by GitHub:

- `main` needs a PR with 1 approval and a green `dart-check`. The job token cannot approve its own
  PR and cannot change workflow files. The owner keeps the admin bypass for their own pushes.
- Agent jobs have a read-only job token: they cannot push, comment, label or merge, whatever they
  run. Writing jobs run no agent and no repository code.
- The Claude token (`CLAUDE_CODE_OAUTH_TOKEN`) is a secret of the environment `claude`, which only
  accepts runs from `main`. Release secrets are not used in this workflow.

Depends on inputs and on the agent:

- The agent can run code (`flutter test`), so it can read everything in its job, including the
  Claude token. Therefore it only reads owner text (issue and owner comments, prepared as a file).
  It has no `gh`, no `git push`, no `curl` and no web tools.
- The allowed shell commands narrow mistakes; they are not a sandbox.
- An owner issue that quotes untrusted text is the remaining way in. Keep issues in your own words.

Known limits:

- Only `ci.yml` runs on `claude/` branches; Android, iOS and store workflows do not.
- Jobs wait for each other across the matrix: `publish` starts when every `implement` entry is done,
  so the first PR of a run can come up to about 3 hours after the start.
- Artifacts of a public repository are public for 7 days. The workflow uploads only a fixed list
  (result, question, PR title and text, patches).
- Writing jobs check what they publish: commits only by `claude[bot]`, nothing under `.github/`, no
  closing keyword for another issue; PR and comment texts lose such keywords and `@`-mentions. An
  agent that breaks out could still hand over a wrong artifact for another picked issue; the damage
  stays on that issue's branch and PR, which the owner reviews.
- Matrix jobs run in list order in practice; GitHub does not promise it.
- Scheduled workflows of public repositories stop after 60 days without activity; enable it again
  under Actions.
- Runs count against the same Claude plan limit as interactive use.

## One-time setup

1. In a terminal: `claude setup-token`, then store the token yourself:
   `gh secret set CLAUDE_CODE_OAUTH_TOKEN --env claude`. If it leaks, revoke it and make a new one.
2. Repository setting "Allow GitHub Actions to create and approve pull requests": on.
3. Environment `claude`: deployment branch `main` only.
4. Branch protection of `main`: PR with 1 approval, required check `dart-check`, no force push, no
   deletion, admins not enforced.
5. Labels: `claude`, `claude-laeuft`, `claude-pr`, `claude-rueckfrage`, `claude-fehler`.
