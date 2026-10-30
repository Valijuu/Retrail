# Retrail — agent guide

Retrail is a GPS route tracker for longboard and skate rides, a Flutter (Android + iOS) port of an
Android Jetpack Compose app. It works with **SpecDD**.

**Before working on this project, read [`AGENTS.md`](AGENTS.md) and follow it.** It points to
`.specdd/bootstrap.md` (the SpecDD rules). After that, read `.specdd/bootstrap.project.md` (Retrail's
process: EXACT handoff for `lib/domain`, test disciplines, tasks vs. GitHub issues, git, verification).

## Where things are

- **Contracts:** `.sdd` files next to the code they govern. The root is [`retrail.sdd`](retrail.sdd) (platform,
  structure, global rules), then `lib/lib.sdd` (architecture and conventions), then one spec per area,
  feature or domain file. `specdd resolve <path>` lists the chain for a file; `specdd lint` checks syntax.
- **Process:** `.specdd/bootstrap.project.md`.
- **Why things are the way they are:** `docs/specs/history/` (old phase specs, plans, map and token notes)
  and `docs/decisions/` (decisions made after the SpecDD migration). These explain decisions; they are
  not requirements. `Spec N` in a code comment refers to `docs/specs/history/NN-*.md`.
- **SpecDD skills (plugin):** `docs/specdd-skills.md`.
- **German copy:** `lib/l10n/glossary_de.md`.
- **Release and store:** `docs/android-release.md`, `docs/play-store.md`, `docs/ios-sideloading.md`.

## Keep it current

A change that alters behaviour, structure or a rule updates the governing `.sdd` (or
`bootstrap.project.md` for process rules) in the same commit. This file only points the way; it holds
no rules of its own.
