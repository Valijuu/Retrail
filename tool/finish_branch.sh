#!/usr/bin/env bash
# Finishes a feature branch in one step, so no branch or worktree is left behind (#153):
#   rebase onto origin/<base>, fast-forward <base>, push <base>, remove the branch's worktree,
#   delete the branch locally and on origin, prune.
#
#   tool/finish_branch.sh <branch> [base]   finish <branch> (base: main)
#   tool/finish_branch.sh --check [base]    only list possible leftovers: branches with no commit outside
#                                           <base> (also after a rebase), and worktrees on them. A branch
#                                           that was just created looks the same: check before deleting.
#
# Run it from any worktree of the repo. All checks run before the first change: it stops on
# uncommitted changes, on commits on origin/<branch> or local <base> that would be lost, on a
# rebase conflict, or when <base> cannot be fast-forwarded.
set -euo pipefail

die() { echo "finish_branch: $*" >&2; exit 1; }

# True when every commit of $1 is already in $2 by patch (git cherry shows no "+").
fully_in() { ! git cherry "$2" "$1" 2>/dev/null | grep -q '^+'; }

worktree_of() {
  git worktree list --porcelain | awk -v ref="refs/heads/$1" '
    /^worktree / { path = substr($0, 10) }
    $0 == "branch " ref { print path }'
}

check() {
  local base="$1" found=0 branch path
  git fetch -q --prune origin
  git rev-parse -q --verify "refs/remotes/origin/$base" >/dev/null || die "no origin/$base"
  while read -r branch; do
    [ "$branch" = "$base" ] && continue
    if fully_in "$branch" "origin/$base"; then
      path="$(worktree_of "$branch")"
      echo "leftover? local branch $branch has no commits outside $base (merged, or started and still empty)${path:+, worktree $path}"
      found=1
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads)
  while read -r branch; do
    case "$branch" in origin/HEAD|origin/"$base"|origin) continue ;; esac
    if fully_in "$branch" "origin/$base"; then
      echo "leftover? remote branch ${branch#origin/} has no commits outside $base (merged, or pushed while empty)"
      found=1
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin)
  [ "$found" = 0 ] && echo "no leftovers: every branch has commits that are not in $base"
  return 0
}

if [ "${1:-}" = "--check" ]; then
  check "${2:-main}"
  exit 0
fi

branch="${1:-}"
base="${2:-main}"
[ -n "$branch" ] || die "usage: tool/finish_branch.sh <branch> [base] | --check [base]"
[ "$branch" != "$base" ] || die "refusing to finish the base branch itself"
git rev-parse -q --verify "refs/heads/$branch" >/dev/null || die "no local branch $branch"

git fetch -q --prune origin
git rev-parse -q --verify "refs/remotes/origin/$base" >/dev/null || die "no origin/$base"

# Every check runs before the first change, so a refusal leaves everything as it was.
work="$(worktree_of "$branch")"
[ -n "$work" ] || die "$branch is not checked out in any worktree; check it out first"
[ -z "$(git -C "$work" status --porcelain)" ] || die "$branch has uncommitted changes in $work"
remote_branch=""
if git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
  remote_branch="origin/$branch"
  git merge-base --is-ancestor "$remote_branch" "$branch" \
    || die "origin/$branch has commits that $branch lacks; pull them first"
fi
if git rev-parse -q --verify "refs/heads/$base" >/dev/null; then
  git merge-base --is-ancestor "$base" "origin/$base" \
    || die "local $base has commits that are not on origin/$base; push or drop them first"
fi
base_work="$(worktree_of "$base")"
[ -z "$base_work" ] || [ -z "$(git -C "$base_work" status --porcelain)" ] \
  || die "$base has uncommitted changes in $base_work"
main_work="$(git worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}')"
if [ "$work" = "$main_work" ] && [ -n "$base_work" ]; then
  die "$branch is in the main worktree and $base is checked out in $base_work; switch one of them first"
fi

git -C "$work" rebase "origin/$base" || die "rebase conflicts in $work; resolve them, then run again"
git merge-base --is-ancestor "origin/$base" "$branch" || die "$base cannot be fast-forwarded to $branch"

# Push first (origin refuses anything but a fast-forward), then move the local base.
git push -q origin "refs/heads/$branch:refs/heads/$base" || die "push refused: origin/$base moved; run again"
if [ -n "$base_work" ]; then
  git -C "$base_work" merge -q --ff-only "$branch"
else
  git branch -f "$base" "$branch"
fi

# The main worktree cannot be removed; there the branch is left by checking out the base.
if [ "$work" = "$main_work" ]; then
  git -C "$work" checkout -q "$base"
else
  git worktree remove "$work"
fi

[ "$(git rev-parse "$branch")" = "$(git rev-parse "$base")" ] || die "$branch is not equal to $base after the fast-forward"
git branch -D "$branch" >/dev/null
if [ -n "$remote_branch" ]; then
  git push -q origin --delete "refs/heads/$branch"
fi
git fetch -q --prune origin
git worktree prune

echo "finished $branch: $base is at $(git rev-parse --short "$base"), branch and worktree removed"
check "$base"
