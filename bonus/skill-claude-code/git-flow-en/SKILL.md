---
name: git-flow
description: Helps with the git flow (AVH edition) workflow to open/close features, releases and hotfixes. Use when the user asks to "open/create/close a feature", "start/finish a release", "open a hotfix", "bump the version", "generate a changelog", or describes a task that should become a feature branch. Orchestrates the ~/.zshrc functions (gfs, gff, gfrs, gfrf, gfhs, gfhf, gup) and builds commits/changelog following Conventional Commits + SemVer from a real analysis of the diff and the history.
---

# git flow — features, releases and hotfixes

This project uses **git flow (AVH edition)** with helper functions already defined in
the user's `~/.zshrc`. The skill **does not reimplement** the workflow: it decides
names/versions, runs the right functions and writes the text (commits and changelog).

## Available functions (in ~/.zshrc)

| Function | What it does |
| --- | --- |
| `gup` | checkout+pull of `develop` and `master`/`main`; automatic stash/pop; returns to the original branch. |
| `gfs <name>` | Opens a feature: stash → `gup` → `git flow feature start` → **`git flow feature publish`** → `git stash pop` on the feature. |
| `gff [name] [--no-push]` | Closes a feature (everything committed): `gup` → `git flow feature finish` (removes the local and remote branch) → push of `develop`. Without a name, uses the current branch. |
| `gfrs [--minor\|--major\|--patch]` | Opens a release: `git fetch --tags` → computes the next version (**default: minor bump**) → handles uncommitted files (see below) → if the branch already exists (local/origin) just checks it out; otherwise `gup` → `git flow release start` → **`git flow release publish`**. |
| `gfrf [version] [-f <file>\|-m <msg>] [--no-push]` | Closes a release: `gup` → `git flow release finish` (merges with no editor + annotated tag with the changelog) → `checkout master && git push && git push --tags` → `checkout develop && git push`. |
| `gfhs` | Opens a hotfix: `git fetch --tags` → computes the next version (**patch bump**) → stashes uncommitted changes → if the branch already exists (local/origin) checkout + `stash pop`; otherwise `gup` → `git flow hotfix start` (based on `master`) → **`git flow hotfix publish`** → `stash pop` on the hotfix. |
| `gfhf [version] [-f <file>\|-m <msg>] [--no-push]` | Closes a hotfix: same as `gfrf` (same internal `_gf_finish` logic), with `git flow hotfix finish`. |
| `gcMsg <type> <scope> "msg" [--no-push] [--breaking]` | Conventional Commits commit: `git add .` → commit → pull → push. `<scope>` optional. |

Always run via the user's shell (the functions live in `.zshrc`). If a command
fails, **stop and show the output** — do not work around it.

Project conventions:
- **Tags:** SemVer **without** the `v` prefix — just `major.minor.patch` (e.g. `1.5.0`).
- **Commits:** Conventional Commits, message in Portuguese, imperative, lowercase, no trailing period.

---

## FEATURE

### Open

1. **Choose the name** from the task discussed in the conversation: kebab-case, short,
   immediately understandable, without the `feature/` prefix (git flow adds it).
   - "social login with Google" → `google-login`
   - "duplicated shipping calculation" → `duplicated-shipping`
   - When in doubt between two names, propose one and confirm before creating.
2. Check repo + git flow initialized (`git config gitflow.branch.develop`).
3. Run `gfs <name>`.
4. Confirm: branch created **and published to origin**; if there were uncommitted
   changes, they were carried over to the feature (`git status`).

### Committing during the feature

For each logical unit of change, build the commit with `gcMsg` **analyzing the real
diff** (`git status`, `git diff`, `git diff --staged`):
- `<type>`: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- `<scope>`: module/area in one word (e.g. `auth`, `shipping`, `images`); omit if there is no clear one.
- `"msg"`: describes **what** changed, based on the actual changes — not on the feature name.
- `--breaking`: only when it breaks compatibility of an API/contract/public interface.
- `--no-push`: when the user asks not to push yet.
- `gcMsg` runs `git add .`. If only part of the changes should go in, do a selective
  `git add` + manual `git commit` following the same convention.

### Close

1. Ensure `git status` is clean; if not, build the pending commits with `gcMsg`.
2. Be on the feature branch (or pass the name).
3. Run `gff` (or `gff <name>` / `gff --no-push`).
4. `gff` runs `gup` → `git flow feature finish` (merge into `develop` + remove the branch) → push of `develop`.
5. Merge conflict during the finish → warn the user and **do not force**: they resolve it and run
   `git flow feature finish <name>` again.

---

## RELEASE

> **Opening and closing are separate steps, never chained.** `gfrs` creates the branch
> and stops; the user works on it (version bump, changelog, final adjustments, commits
> with `gcMsg`) for as long as they want; only afterwards, on an explicit request, is
> `gfrf` run. "Close the release" = only `gfrf` (the branch already exists). If there
> is no release branch, ask whether to open one — do not assume open+close.

### Open

1. **Before running `gfrs`, check `git status`.** If there are uncommitted files:
   - **On the `develop` branch:** commit them first with `gcMsg <type> <scope> "msg"`
     (message derived from the real diff). Only then run `gfrs`. — If `gfrs` is called
     with a dirty `develop`, it **aborts** asking for this.
   - **On any other branch:** run `gfrs` directly. It stashes the changes, creates and
     **publishes** the `release/<version>`, and does `stash pop` there leaving the
     changes restored (uncommitted). Then commit those changes on the release with
     `gcMsg <type> <scope> "msg"` (the branch already has an upstream).
2. Decide the SemVer increment. **Default: minor** (`gfrs`). Use `--major` only if
   there is an accumulated breaking change; `--patch` for a fixes-only release.
   - `gfrs` finds the latest tag and computes the next one (e.g. `1.4.2` → `1.5.0`).
   - If `release/<version>` already exists locally or on origin, `gfrs` just checks it
     out (does not recreate it); if it is local and not yet on origin, it publishes it.
3. Run `gfrs` (or `gfrs --major` / `gfrs --patch`).
4. `gfrs` runs `gup`, creates the branch based on `develop` and **publishes it to origin**
   (`git flow release publish`). Confirm the computed version and the branch created.
5. Only final release adjustments go on this branch (version bump in files,
   last-minute fixes) — committed with `gcMsg`.

### Close

1. Ensure `git status` is clean on the release branch.
2. **Write the changelog** for the version (it is "screen 2" of the finish, the message
   of the annotated tag). Generate it by analyzing the history since the latest tag:
   ```
   git log --no-merges --pretty=format:'- %s' <latest-tag>..HEAD
   ```
   Organize it by section (e.g. `### Features`, `### Fixes`, `### Breaking changes`),
   in Portuguese, readable — do not paste the raw list of commits. Save it to a temporary
   file and pass it with `-f`:
   ```
   gfrf -f /path/CHANGELOG-1.5.0.md
   ```
   (Alternative: `gfrf -m "multi-line text"` — the function routes through a file
   internally. If nothing is passed, `gfrf` generates a simple automatic changelog.)
3. `gfrf` runs `gup`, then `git flow release finish`:
   - merges into `master` and `develop` with the default message (no editor opened);
   - annotated tag `major.minor.patch` (no `v`) with the changelog;
   - removes the release branch (local and remote).
   Then: `checkout master` + `git push && git push --tags`, `checkout develop` + `git push`.
4. **Merge conflict** → `gfrf` stops and shows how to resume. Tell the user to resolve
   it manually; **do not force**. The changelog file is preserved so they can finish
   with `git flow release finish -f <file> <version>`.
5. Confirm to the user: version tagged, `master` and `develop` published.

---

## HOTFIX

Urgent fix that comes straight off `master` (production), without going through `develop`.

> **Opening (`gfhs`) and closing (`gfhf`) are separate steps**, as with a release — the
> user fixes and commits on the branch between the two.

### Open

1. If there are uncommitted files, `gfhs` already stashes everything and restores it
   (`stash pop`) on the hotfix branch it creates — no need to commit first.
2. Run `gfhs` (no arguments). It:
   - finds the latest tag from origin and computes the next one **bumping the patch**
     (e.g. `2.3.1` → `2.3.2`);
   - if `hotfix/<version>` already exists (local or origin), just checks it out + `stash pop`;
   - otherwise: `gup` → `git flow hotfix start <version>` (based on `master`) →
     **`git flow hotfix publish`** → `stash pop`.
3. Make the fix and commit with `gcMsg` (message derived from the real diff).

### Close

1. Ensure `git status` is clean on the hotfix branch.
2. **Write the changelog** for the hotfix (it is "screen 2" of the finish / the tag
   message), analyzing `git log --no-merges --pretty=format:'- %s' <latest-tag>..HEAD`.
   Organize it readably, in Portuguese. Pass it with `-f <file>` (or `-m`).
3. Run `gfhf` (or `gfhf <version>` / `gfhf --no-push`). It runs `gup` and
   `git flow hotfix finish`:
   - merges into `master` **and** `develop` without opening an editor;
   - annotated tag `major.minor.patch` (no `v`) with the changelog;
   - removes the hotfix branch;
   - `checkout master` + `git push && git push --tags`, `checkout develop` + `git push`.
4. **Merge conflict** → `gfhf` stops and shows how to resume; the changelog file is
   preserved. Warn the user; **do not force**.
5. Confirm: version tagged, `master` and `develop` published.

---

## Notes

- `master`/`main`: the functions automatically detect which one exists (`gitflow.branch.master`).
- `gfrf` and `gfhf` share the internal `_gf_finish` function — same finish logic.
- Never run `git flow init`, `git push --force` or `git tag -d` without the user asking.
