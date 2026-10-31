# SpecDD project specific overrides

Project rules for Retrail. They add to `bootstrap.md` and narrow it where stated. The subject contracts
live in the `.sdd` files (root: `/retrail.sdd`); this file holds the working process.

## Sources of truth

- `.sdd` specs are the only binding description of behaviour and boundaries. Detail below a spec is
  pinned by the tests it owns.
- `docs/specs/history/` holds the old phase specs, plans and notes. It is rationale ("why"), never a
  requirement and never write authority. Specs point to it through `References`.
- `docs/decisions/NNNN-<title>.md` holds decisions taken after the SpecDD migration (context, decision,
  rejected alternatives), referenced from the spec they shaped.
- Before changing or removing a `Must`, `Must not` or `Forbids` entry, read the history files, decision
  notes and GitHub issues (`#N`) it references, so a decision is not undone without knowing its reason.
- Real ride or GPS data never enters the repository; real traces stay in gitignored fixtures.
- Tests live under `/test/<area>/`, not next to the code. Each test path is owned by the spec that lists it in
  `Owns` (for example `/lib/map/map.sdd` owns `/test/map`, `/lib/domain/heading.sdd` owns
  `/test/domain/heading_test.dart`). To resolve a test file, use the spec of the matching `/lib/<area>/`
  file or directory; `test/foundation`, `test/support` and `test/e2e` belong to `/lib/lib.sdd`.
- Rules in `Must` entries that cite an issue (`#N`) protect a fix; read the issue before changing that code.

## Implementation: who changes what (the `Change` step)

Pick the test discipline by the target, before writing code:

- **Pure logic in `/lib/domain/` → EXACT.** Side-effect-free input → output logic with no widget tree,
  Riverpod wiring, Drift database or network access. `Change` runs the global `vaju:tdd-dart` workflow (plugin `vaju`) and
  nothing else: `Skill({ skill: "vaju:tdd-dart" })` → `/vaju:test-list-dart` → `/vaju:red-dart` → `/vaju:green-dart` →
  `vaju:refactor` subagent → final Opus review.
  - The test list comes from the governing spec: every `Scenario` and every `Example` becomes at least
    one test; `Must` and `Must not` add the boundary cases.
  - Do not use SpecDD's own test-derivation or implement skills for these targets.
- **Widgets, Riverpod providers, Drift DAOs → Red-Green-Refactor.** Test first, watch it fail for the
  right reason (compile error, then assertion), minimal code to pass, refactor.
- **Platform integration, golden and end-to-end tests → alongside the implementation.** GPS pipeline,
  `flutter_foreground_task`, notifications and Live Activity, golden and E2E flows depend on platform or
  timing state, so a clean red first is not required.
- Every @FollowTracker change keeps `/test/domain/follow_tracker_scenarios_test.dart` green.
  `--dart-define=FOLLOW_SCENARIOS_ALL=true` runs the skipped pairs, `FOLLOW_SCENARIOS_REPLAY=<id>|<noise>|<seed>`
  replays one run; the real-ride replay reads the gitignored `test/fixtures/real_rides.json`.

## Tasks and GitHub

- `Tasks` hold only work in progress for the spec's subject. The task id `#N` is the GitHub issue number.
- Deferred findings, bugs and "revisit later" decisions become GitHub issues at once; feature ideas become
  draft items on the project board (https://github.com/users/Valijuu/projects/1). Neither lives only in a spec.
- Mark a task `[x]` only when `flutter analyze` is clean, `flutter test` passes and, for EXACT work, the
  final Opus review is done. Use `[!]` for blocked (for example a pending device check) and `[?]` for an
  open decision.
- When the feature is merged, remove its done tasks; the spec then describes the resulting state.

## New feature workflow

1. The idea is a board draft; taking it on creates an issue `#N` and a branch `feature/<name>` off `main`.
2. Spec first, no code: extend or add the `.sdd` (`Purpose`, `Must`, `Must not`, `Scenario`, `Example`,
   `Tasks` with `#N`, `Done when`). A real trade-off also gets a decision note referenced from the spec.
3. The Operator reviews the spec before implementation starts.
4. Implement task by task with `Resolve -> Read -> Authorize -> Change -> Verify -> Report`, using the
   discipline above for `Change`.
5. Finish with an Opus review against the spec, then rebase onto `main`, fast-forward `main`, delete the
   branch and close the issue.

Every change that alters behaviour updates the governing spec in the same commit.

## Git

- One short-lived branch per feature or fix; `main` stays green and linear. Rebase onto `main` and
  fast-forward, never merge. Delete the branch afterwards.
- Run `dart format` on every changed Dart file (default tall style, no formatter config). The
  `.githooks/pre-commit` hook rejects unformatted staged Dart files (`git config core.hooksPath .githooks`);
  formatting-only commits go into `.git-blame-ignore-revs`.
- The `.githooks/pre-commit` hook also runs `gitleaks git --staged` (this repo's `core.hooksPath` bypasses the global hook); the repository is public, so no secret or real location data may be committed. Install gitleaks via `claude-config/bootstrap`.
- Commit messages follow Conventional Commits in English: `type(scope): summary`.
- `git config blame.ignoreRevsFile .git-blame-ignore-revs` once per clone hides formatting-only commits in blame.
- Stage only your own files; other tools edit `README.md` and `.claude/`.

## Verification

- Done means `flutter analyze` is clean and `flutter test` passes; spec changes also pass `specdd lint`.
- iOS builds only on GitHub Actions (`.github/workflows/ios-build.yml`); Swift and Xcode-project changes are
  verified by that workflow going green. Device testing sideloads per `docs/ios-sideloading.md`
  (`tool/ios_fetch_build.sh`); the pre-push hook fetches a build after app pushes to `main`.
- Device checks that cannot run headless stay open as `[!]` tasks or issues until done on a device.

## Debugging

Use the `superpowers:systematic-debugging` skill when a bug spans several files, is intermittent, has several plausible
causes or a quick fix already failed; when unsure, use it. Fix trivial single-file bugs directly with a short
explanation.

## Releases

Android releases follow the global `play-release` skill and `docs/android-release.md`; store texts and form
answers live in `docs/play-store.md`. The privacy policy and imprint in `/site` change in the same change
whenever the app starts sending data somewhere new.
