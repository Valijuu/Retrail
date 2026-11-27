# Claude issues (GitHub Actions)

The workflow `.github/workflows/claude-issues.yml` hands issues to Claude Code and opens a PR per
issue. It replaces the earlier cloud routine, which had no Flutter and pushed with the owner's admin
token.

## Handing over an issue

- Only the owner sets the label `claude`. Nothing starts at once: every 3 hours (and on a manual
  "Run workflow") the workflow picks up to 3 issues.
- It takes the oldest open issues with `claude` that the owner wrote and labelled, and that have
  none of `claude-pr`, `claude-rueckfrage`, `claude-laeuft`, `claude-fehler`.
- The picked issues are worked one after the other, oldest first. Before each one the workflow
  checks again that it is still open and still labelled `claude`.
- Do not paste text from third parties into a `claude` issue or into an owner comment on it: owner
  text is the only issue text the agent reads, and it trusts it.

## Labels

| Label | Set by | Meaning |
|---|---|---|
| `claude` | owner | hand the issue to Claude |
| `claude-laeuft` | workflow | a run works on it now |
| `claude-pr` | agent | PR is open; `claude` is removed |
| `claude-rueckfrage` | agent | question in a comment; `claude` stays. Answer in the issue, then remove `claude-rueckfrage` |
| `claude-fehler` | workflow | the run failed (link in a comment). Remove it to try again |

If a runner dies, `claude-laeuft` can stay behind: remove it by hand.

## Review order

1. CodeRabbit first. The repository has fewer than 10 stars, so CodeRabbit does not review by itself:
   a workflow step (no agent) posts `@coderabbitai review` and waits up to 10 minutes. If a review
   comes, a second agent step fixes the findings and comments what it did.
2. If CodeRabbit reports its limit, or stays silent, an Opus step reviews features at once and fixes
   critical and major findings. Docs and bugfixes rely on the tests. A PR comment names the reviewer.
3. A last job without an agent starts `ci.yml` on each branch with an open PR, because a PR opened
   with the job token does not start the CI by itself. Only `ci.yml` runs there; the Android, iOS and
   store workflows do not.

## Safety model

What is enforced by GitHub:

- `main` needs a PR with 1 approval and a green `check`. The job token cannot approve its own PR,
  so the agent cannot merge. The owner keeps the admin bypass for their own pushes.
- The job token is not an admin and cannot change files under `.github/workflows`.
- The Claude token (`CLAUDE_CODE_OAUTH_TOKEN`) is a secret of the environment `claude`, which only
  accepts runs from `main`. Scheduled runs always use the workflow file from `main`; a manual run
  from another branch is refused by the environment.
- Release secrets are not in this workflow.

What depends on the agent and the inputs:

- The agent can run code (`flutter test`), so anything in its job (job token, Claude token) must be
  treated as readable by it. That is why it only gets text by the owner and by CodeRabbit: the issue
  text and owner comments come from a file the workflow prepares; it has no `gh issue view`,
  `gh pr view`, `gh api` or web tools.
- The shell list (exact git, gh, flutter, dart and specdd commands) narrows mistakes; it is not a
  sandbox. "Never merge, never push to main" is enforced by GitHub, not by the prompt.

## One-time setup

1. In a terminal: `claude setup-token`, then store it yourself:
   `gh secret set CLAUDE_CODE_OAUTH_TOKEN --env claude`.
2. Repository setting "Allow GitHub Actions to create and approve pull requests" is on.
3. Environment `claude` accepts the branch `main` only.

Runs count against the same Claude plan limit as interactive use. If the token leaks, revoke it and
create a new one. Scheduled workflows of public repositories stop after 60 days without activity in
the repository; enable it again under Actions.
