---
name: gitea-tea-cli
description: Use when working with Gitea repositories, issues, pull requests, releases, or related terminal workflows through the tea CLI.
---

# Gitea Tea CLI Skill

Use this skill when the user wants to interact with a Gitea repository through the `tea` command-line tool.

`tea` is the official Gitea CLI for working with repositories, issues, pull requests, releases, labels, milestones, notifications, and server-side workflows. It supports multiple named Gitea logins and can infer repository context from the current Git repository when possible.

## Core Assumptions

Prefer `tea` over raw API calls unless the user specifically asks for the API.

Prefer read-only inspection commands before mutating state.

When unsure about command syntax, run:

```bash
tea --help
tea <command> --help
```

Do not assume `gh` syntax is exactly supported. `tea` is similar to `gh`, but not identical.

## Safety Rules

Before destructive or irreversible actions, show the exact command and ask for confirmation.

Confirmation is required for:

```bash
tea pulls merge
tea pr merge
tea issues close
tea pr close
tea releases delete
tea repos delete
tea repo rm
```

Do not expose tokens. Never print `tea` config files containing credentials.

## Authentication

Check available logins:

```bash
tea login list
# or
tea logins list
```

Add a login:

```bash
tea login add --name <name> --url <gitea-url> --token <token>
```

Use a specific login when needed:

```bash
tea --login <name> <command>
```

`tea` stores config under `$XDG_CONFIG_HOME/tea` when configured normally.

## Repository Context

When inside a Git repo hosted on Gitea, prefer allowing `tea` to infer the repo.

If outside a repo, or if inference fails, pass:

```bash
--repo <owner>/<repo>
```

Example:

```bash
tea issues list --repo myorg/myrepo
```

`tea` works best when the local main branch tracks the upstream repo and assumes local Git state has already been published before PR operations.

## Output Format

Prefer machine-readable output when parsing:

```bash
tea issues list --output json
tea pulls list --output json
tea repos list --output json
```

If JSON is unavailable for a subcommand, use table output and explain the limitation.

## Common Workflows

### Inspect current repo

```bash
git remote -v
git branch --show-current
tea repos view
```

### List issues

```bash
tea issues list --state open
tea issues list --state closed
tea issues list --state all
```

### View an issue

```bash
tea issues <number>
tea issues <number> --comments
tea issues <number> --fields index,title,body,comments
```

Do not use `tea issues view <number>` unless `tea issues --help` shows a `view` subcommand. In the local `tea` version used here, `issues` accepts the issue index directly; `tea issues view <number>` is parsed like a list command and returns the issue list instead of issue details.

### Comment on an issue

```bash
tea comment <number> "message"
```

`tea issues` has no `comment` subcommand in the local CLI. Comments are created with the top-level `tea comment` command.

### Create an issue

```bash
tea issues create --title "Title" --body "Body"
```

### List pull requests

```bash
tea pulls list
# or, if aliases are supported:
tea pr list
```

### View a pull request

```bash
tea pulls view <number>
```

### Checkout a pull request locally

```bash
tea pulls checkout <number>
```

### Create a pull request

Before creating a PR, verify the branch is pushed:

```bash
git status
git branch --show-current
git push -u origin HEAD
```

Then create the PR:

```bash
tea pulls create --title "Title" --body "Body" --base main --head <branch>
```

If needed:

```bash
tea pulls create --repo <owner>/<repo> --title "Title" --body "Body" --base main --head <branch>
```

### Review a pull request

```bash
tea pulls review <number> --approve --comment "LGTM"
tea pulls review <number> --reject --comment "Requested changes"
tea pulls review <number> --comment "Review comment"
```

### Merge a pull request

Only after confirmation:

```bash
tea pulls merge <number>
```

### Releases

List releases:

```bash
tea releases list
```

Create a release:

```bash
tea releases create <tag> --title "Title" --note "Release notes"
```

Create a release with an asset:

```bash
tea releases create <tag> --asset ./dist/app.tar.gz
```

## Troubleshooting

If `tea` cannot detect the repo:

```bash
git remote -v
tea issues list --repo <owner>/<repo>
tea issues <number> --repo <owner>/<repo>
```

If authentication fails:

```bash
tea login list
tea login add --name <name> --url <url> --token <token>
```

If a PR command fails, check that the branch exists remotely:

```bash
git status
git branch --show-current
git ls-remote --heads origin
git push -u origin HEAD
```

## Agent Behavior

When asked to perform a workflow:

1. Inspect local Git state.
2. Inspect `tea` login/repo context.
3. Prefer read-only commands first.
4. Summarize findings.
5. For mutations, show the command before running it unless the user explicitly authorized the action.
6. For destructive actions, always require confirmation.
