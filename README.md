# Dotfiles

Personal dotfiles managed with GNU Stow.

Run `./install.sh` to install packages, then `./stow-dotfiles.sh` to select
configs and enable automatic restowing after merge pulls. Yazi is included;
see [its configuration notes](yazi/README.md) for shortcuts and setup.

## Codex learning preferences

The `codex` package includes [learn-by-connection](codex/.codex/skills/learn-by-connection/SKILL.md),
which teaches through familiar connections, one logical chunk at a time, waiting
for readiness before continuing. Its source is a living document: ask Codex to
remember a teaching preference or refine the skill as you learn what works.

Select `codex` in `./stow-dotfiles.sh` to enable it on each machine. If this
machine previously skipped Codex, remove only `codex=n` from the local
`.decisions` file first so the installer asks again. To link the package directly
without changing saved installer choices, run from this repository:

```bash
stow --no-folding -d "$PWD" -t "$HOME" codex
```

This links global instructions into `~/.codex/AGENTS.md` and exposes the skill
under both `~/.codex/skills` and `~/.agents/skills`, using one source. Start a new
Codex session after installation. Explanation requests use the skill by default;
you can also invoke it explicitly with `$learn-by-connection`. Stow symlinks keep
edits in this repo; commit and pull those changes to share iterations between
machines. With a custom `CODEX_HOME`, also link the tracked global `AGENTS.md`
into that directory, preserving any existing instructions there.

## Local Secrets

Machine-specific paths and secrets should live in `~/.bash_secrets`, which is sourced by `.bashrc` before aliases and functions are defined.

Create the following variables there:

```bash
export DOTFILES_DEV_DIR="$HOME/Dev"
export HEROUI_INSTALL_SCRIPT="$HOME/heroui.sh"
export DEV_DIRECTORY="$HOME/dev"
```

- `DOTFILES_DEV_DIR`: directory used by the `dev` shell alias.
- `HEROUI_INSTALL_SCRIPT`: local HeroUI install script referenced by the Codex and Claude HeroUI skills.
- `DEV_DIRECTORY`: Used by Zellij and potentially more
