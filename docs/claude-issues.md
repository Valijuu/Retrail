# Claude issues (GitHub Actions)

The workflow `.github/workflows/claude-issues.yml` hands issues to Claude Code and opens a PR.
It replaces the earlier cloud routine, which had no Flutter and pushed with the owner's admin token.

## Handing over an issue

- Only the owner sets the label `claude`. Setting it starts the workflow at once; a schedule
  (every 3 hours) picks up what is left.
- One issue per run, always the oldest open issue with `claude` that has neither `claude-pr` nor
  `claude-rueckfrage`. Runs wait for each other (`concurrency`), so the queue is worked in order.
- The label event is ignored unless the owner set it. The picker checks again that author and label
  actor are the owner. Anything else in the issue or its comments counts as data, not as orders.
- Do not paste text from third parties into a `claude` issue: it comes from the owner and is trusted.

## Results

1. **Pull request:** branch `claude/issue-<N>`, `Closes #N`. The issue gets `claude-pr` and loses
   `claude`. The CI is dispatched on the branch by a separate job, because a PR opened with the job
   token does not start it.
2. **Question:** a comment and the label `claude-rueckfrage` (stays together with `claude`). To
   answer: reply in the issue and remove `claude-rueckfrage`. The next run picks it up again.

## Review order

1. CodeRabbit first. The repository has fewer than 10 stars, so it does not review by itself: the
   workflow asks with the PR comment `@coderabbitai review`.
2. If CodeRabbit reports its review limit, the agent switches to an Opus subagent at once for
   features (also after 10 silent minutes). Docs and small bugfixes rely on the tests. A PR comment
   says which reviewer was used.

## Safety rails

- The workflow file always comes from `main`; the agent cannot change its own rules.
- The Claude token (`CLAUDE_CODE_OAUTH_TOKEN`) is a secret of the environment `claude`, which only
  accepts runs from `main`.
- The job uses the Actions token, not an admin token: branch protection on `main` binds it, and it
  cannot change files under `.github/workflows`.
- No web tools; shell limited to git, `gh issue`, `gh pr`, flutter, dart and specdd.
- The agent never merges and never pushes to `main`. The owner merges every PR.

## One-time setup

1. `claude setup-token` in a terminal, then store the result yourself:
   `gh secret set CLAUDE_CODE_OAUTH_TOKEN --env claude`.
2. Repository setting "Allow GitHub Actions to create and approve pull requests" is on.
3. Environment `claude` accepts the branch `main` only.

Runs count against the same Claude plan limit as interactive use. If the token leaks, revoke it and
create a new one.
