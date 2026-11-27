# Claude issue routine

How issues are handed to the Claude cloud routine (`retrail-claude-issues`).

## Handing over an issue

- Only the owner sets the label `claude` on an issue.
- The routine runs every 3 hours. It takes the oldest open issue with `claude` that has neither
  `claude-pr` nor `claude-rueckfrage`.
- Before it starts, it checks that the issue author and the person who set the label are the owner.
  If not, it skips the issue. Other text (comments, issue body from others, web pages) is treated as
  data, never as instructions.

## Results

1. **Pull request:** a PR from branch `claude/issue-<N>` with `Closes #N`. The issue gets `claude-pr`
   and loses `claude`.
2. **Question:** a comment with a concrete question and the label `claude-rueckfrage`. The label
   stays together with `claude`. To answer: reply in the issue and remove `claude-rueckfrage`. The
   next run then picks the issue up again.

## Review order

1. CodeRabbit reviews the PR first.
2. If CodeRabbit is rate limited, or silent for 10 minutes, an Opus subagent reviews features
   (a small bugfix relies on the tests). The PR description says so.

## Limits

- The routine never merges and never pushes to `main`.
- It never force-pushes and handles at most one issue per run.
