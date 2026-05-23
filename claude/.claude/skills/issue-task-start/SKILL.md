---
name: issue-task-start
description: Use when starting work on a GitHub or Gitea issue — sets up a git worktree under .worktrees/, copies environment files, pushes the branch, and enforces issue-referenced commits throughout.
---

# Issue Task Start

Standardized workflow for picking up a GitHub or Gitea issue and beginning development in an isolated git worktree.

## Workflow

### 1. Fetch issue details

**GitHub:**
```bash
gh issue view <NUMBER> --json number,title,body
```

**Gitea:**
```bash
tea issues view <NUMBER>
```

Derive the branch name from the issue number and title:
```
issue-<NUMBER>-<slug>
# e.g. issue-42-fix-login-timeout
```

Slug rules: lowercase, hyphens only, max ~40 chars, drop articles/punctuation.

### 2. Create branch + worktree

Run from the repo root. The worktree lives under `.worktrees/` in the repo root.

```bash
BRANCH="issue-<NUMBER>-<slug>"
git worktree add .worktrees/$BRANCH -b $BRANCH
```

If the branch already exists remotely:
```bash
git worktree add .worktrees/$BRANCH $BRANCH
```

### 3. Copy environment files

Copy config files that must not be committed into the worktree. Run from the repo root:

```bash
# Copy any .env files present at the root
[ -f .env ] && cp .env .worktrees/$BRANCH/.env

# Copy appsettings.json files (walk subdirs to find them)
find . -maxdepth 3 -name "appsettings.json" \
  -not -path "./.worktrees/*" \
  -not -path "./.git/*" | while read f; do
    dest=".worktrees/$BRANCH/${f#./}"
    mkdir -p "$(dirname "$dest")"
    cp "$f" "$dest"
done

# Copy appsettings.*.json variants
find . -maxdepth 3 -name "appsettings.*.json" \
  -not -path "./.worktrees/*" \
  -not -path "./.git/*" | while read f; do
    dest=".worktrees/$BRANCH/${f#./}"
    mkdir -p "$(dirname "$dest")"
    cp "$f" "$dest"
done
```

Verify before proceeding:
```bash
ls .worktrees/$BRANCH/
```

### 4. Push branch to remote

```bash
git -C .worktrees/$BRANCH push -u origin $BRANCH
```

### 5. Begin work in the worktree

All subsequent work happens inside `.worktrees/$BRANCH/`. Navigate there or pass `-C` to git commands.

## Commit Convention

Every commit while working this issue MUST reference the issue number.

**GitHub format:**
```
feat: add login timeout handling

Closes #42
```

**Gitea format:**
```
feat: add login timeout handling

Fixes #42
```

Inline ref is also acceptable when the subject line naturally includes it:
```
fix(#42): login timeout not reset on activity
```

**Never commit without an issue reference.** If the message body is omitted, put the ref in the subject:
```
chore: update deps (refs #42)
```

## Quick Reference

| Step | Command |
|------|---------|
| View GitHub issue | `gh issue view <N>` |
| View Gitea issue | `tea issues view <N>` |
| Create worktree | `git worktree add .worktrees/<branch> -b <branch>` |
| Copy .env | `cp .env .worktrees/<branch>/.env` |
| Push branch | `git -C .worktrees/<branch> push -u origin <branch>` |
| List worktrees | `git worktree list` |
| Remove worktree | `git worktree remove .worktrees/<branch>` |

## Common Mistakes

**Forgetting to copy env files** — app won't start in the worktree. Always copy before running.

**Working in repo root instead of worktree** — changes bleed across issues. `cd .worktrees/$BRANCH` before any code edits.

**Commits without issue ref** — breaks traceability. Every commit needs the `#N` reference.

**Pushing after committing without issue ref** — fix the commit message before pushing: `git commit --amend`.

## .gitignore Hygiene

Ensure `.worktrees/` is listed in the root `.gitignore` so worktree directories are never accidentally committed:

```bash
grep -q '.worktrees' .gitignore || echo '.worktrees/' >> .gitignore
```
