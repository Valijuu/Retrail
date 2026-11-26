#!/usr/bin/env bash
# Finishes a feature branch in one step, so no branch or worktree is left behind (#153):
#   rebase onto origin/<base>, fast-forward <base>, push <base>, remove the branch's worktree,
#   delete the branch locally and on origin, prune.
#
#   tool/finish_branch.sh <branch> [base]   finish <branch> (base: main)
#   tool/finish_branch.sh --check [base]    only list leftovers: branches whose commits are all in
#                                           <base> (also after a rebase), and worktrees on them
#
# Run it from any worktree of the repo. It stops before pushing if the branch has uncommitted
# changes, if the rebase conflicts, or if <base> cannot be fast-forwarded.
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
  while read -r branch; do
    [ "$branch" = "$base" ] && continue
    if fully_in "$branch" "origin/$base"; then
      path="$(worktree_of "$branch")"
      echo "leftover: local branch $branch is already in $base${path:+ (worktree $path)}"
      found=1
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads)
  while read -r branch; do
    case "$branch" in origin/HEAD|origin/"$base"|origin) continue ;; esac
    if fully_in "$branch" "origin/$base"; then
      echo "leftover: remote branch ${branch#origin/} is already in $base"
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

work="$(worktree_of "$branch")"
[ -n "$work" ] || die "$branch is not checked out in any worktree; check it out first"
[ -z "$(git -C "$work" status --porcelain)" ] || die "$branch has uncommitted changes in $work"

git -C "$work" rebase "origin/$base" || die "rebase conflicts in $work; resolve them, then run again"

git merge-base --is-ancestor "origin/$base" "$branch" || die "$base cannot be fast-forwarded to $branch"
base_work="$(worktree_of "$base")"
if [ -n "$base_work" ]; then
  [ -z "$(git -C "$base_work" status --porcelain)" ] || die "$base has uncommitted changes in $base_work"
  git -C "$base_work" merge -q --ff-only "$branch"
else
  git branch -f "$base" "$branch"
fi
git push -q origin "$base"

# The main worktree cannot be removed; there the branch is left by checking out the base.
main_work="$(git worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}')"
if [ "$work" = "$main_work" ]; then
  [ -z "$base_work" ] || die "$base is checked out in $base_work; switch $work to another branch, then delete $branch"
  git -C "$work" checkout -q "$base"
else
  git worktree remove "$work"
fi

[ "$(git rev-parse "$branch")" = "$(git rev-parse "$base")" ] || die "$branch is not equal to $base after the fast-forward"
git branch -D "$branch" >/dev/null
if git ls-remote --exit-code --heads origin "$branch" >/dev/null; then
  git push -q origin --delete "$branch"
fi
git fetch -q --prune origin
git worktree prune

echo "finished $branch: $base is at $(git rev-parse --short "$base"), branch and worktree removed"
check "$base"
