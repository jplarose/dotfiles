# Dotfiles

Personal dotfiles managed with GNU Stow.

Run `./install.sh` to install packages, then `./stow-dotfiles.sh` to select
configs and enable automatic restowing after merge pulls. Yazi is included;
see [its configuration notes](yazi/README.md) for shortcuts and setup.

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
