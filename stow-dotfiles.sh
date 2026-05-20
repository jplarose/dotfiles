#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
#  Dotfiles Stow Installer
#
#  Assumes ./install.sh has already run and installed required
#  packages such as stow, nvim, zellij, oh-my-posh, beets, yt-dlp, and cbonsai.
#
#  This script only handles:
#    - GNU Stow symlinks for each dotfile package
#    - Backing up any pre-existing files that would conflict
#    - Ensuring ~/.local/bin is on PATH via ~/.bashrc
#
#  Unlink any package with: stow -D <package>
# ─────────────────────────────────────────────────────────

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; }

command_exists() { command -v "$1" &>/dev/null; }

# ── Decisions file ───────────────────────────────────────
# Records each package's last opt-in answer (y/n), so subsequent runs of this
# script and the post-merge hook can apply prior choices without re-prompting.
# Format: one `pkgname=y|n` line per package. Delete the file to reset.
# Lives inside the repo (gitignored) since it's per-machine state about how
# the user has chosen to stow this specific clone.
DECISIONS_FILE="$DOTFILES_DIR/.decisions"

decisions_get() {
    local pkg="$1"
    [[ -f "$DECISIONS_FILE" ]] || return 0
    awk -F= -v pkg="$pkg" '$1 == pkg { print $2; exit }' "$DECISIONS_FILE"
}

decisions_set() {
    local pkg="$1" answer="$2"
    local dir; dir="$(dirname "$DECISIONS_FILE")"
    mkdir -p "$dir"
    local tmp; tmp="$(mktemp "$dir/.decisions.tmp.XXXXXX")"
    if [[ -f "$DECISIONS_FILE" ]]; then
        # `|| true` because grep -v with no surviving lines exits 1, which
        # would abort under `set -e`. An empty filtered file is a valid state.
        grep -v "^${pkg}=" "$DECISIONS_FILE" > "$tmp" 2>/dev/null || true
    fi
    echo "${pkg}=${answer}" >> "$tmp"
    mv "$tmp" "$DECISIONS_FILE"
}

# ── Helpers ──────────────────────────────────────────────
ask() {
    local prompt="$1" default="${2:-y}"
    local hint="[Y/n]"
    [[ "$default" == "n" ]] && hint="[y/N]"
    echo -en "${BOLD}$prompt ${hint}:${NC} "
    read -r answer
    answer="${answer:-$default}"
    [[ "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" == "y" ]]
}

# ── Backup conflicting files ────────────────────────────
# True if $1 itself or any ancestor up to $HOME is a symlink. Used to skip
# files that resolve through a previously-stowed folded symlink: in that
# case `mv "$target"` would follow the symlinked parent and relocate the
# source file out of the dotfiles repo.
target_passes_through_symlink() {
    local p="$1"
    while [[ -n "$p" && "$p" != "/" && "$p" != "$HOME" ]]; do
        [[ -L "$p" ]] && return 0
        p="$(dirname "$p")"
    done
    return 1
}

# Walks the stow package directory and moves any existing
# (non-symlink) files in $HOME to a timestamped backup dir.
backup_stow_conflicts() {
    local pkg="$1"
    local pkg_dir="$DOTFILES_DIR/$pkg"
    local backup_dir="$DOTFILES_DIR/backups/$(date +%Y%m%d_%H%M%S)_$pkg"
    local has_conflicts=false

    while IFS= read -r -d '' file; do
        local rel="${file#$pkg_dir/}"
        local target="$HOME/$rel"
        # Skip when $target or any ancestor is a symlink — those are either
        # already stow-managed or resolve back into the repo, and `mv` on a
        # path under a symlinked parent would yank files out of the repo.
        if [[ -e "$target" ]] && ! target_passes_through_symlink "$target"; then
            if ! $has_conflicts; then
                mkdir -p "$backup_dir"
                has_conflicts=true
            fi
            mkdir -p "$backup_dir/$(dirname "$rel")"
            mv "$target" "$backup_dir/$rel"
            info "Backed up: ~/$rel"
        fi
    done < <(find "$pkg_dir" -type f -print0)

    if $has_conflicts; then
        success "Backups saved to $backup_dir"
    fi
}

# ── Stow wrapper ────────────────────────────────────────
# Backs up any conflicting files, then applies stow.
stow_package() {
    local pkg="$1"

    backup_stow_conflicts "$pkg"

    echo -e "\n${BOLD}Stowing $pkg — symlinks in $HOME:${NC}"
    # --no-folding ensures stow creates real directories and only symlinks
    # individual files, preventing app-generated files from landing in the repo.
    if ! stow -n -v --no-folding -d "$DOTFILES_DIR" -t "$HOME" "$pkg" 2>&1 | grep -E "^(LINK|UNLINK|MV|WARNING)" | sed "s|^|  |"; then
        info "  (no changes — already stowed or empty package)"
    fi

    if stow -v --no-folding -d "$DOTFILES_DIR" -t "$HOME" "$pkg" 2>&1; then
        success "Stowed $pkg. To unlink later: stow -D -d \"$DOTFILES_DIR\" -t \"\$HOME\" $pkg"
    else
        error "Stow failed for $pkg."
        return 1
    fi
}

# ── Package discovery ────────────────────────────────────
# A stow package is a top-level dir containing at least one dotfile or
# dotdir as a direct child (.bashrc, .config/, .claude/, etc.). Non-dotted
# siblings like README.md are allowed because stow's defaults ignore them.
# This matches .githooks/post-merge, so adding a new package only requires
# adding the directory.
is_package_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    local entry
    for entry in "$dir"/.[!.]*; do
        [[ -e "$entry" ]] && return 0
    done
    return 1
}

discover_packages() {
    local dir name
    for dir in "$DOTFILES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        name="$(basename "$dir")"
        is_package_dir "$dir" && printf '%s\n' "$name"
    done | sort
}

# ── Component installer ──────────────────────────────────
# Renders <pkg>/README.md if present (auto-ignored by stow's defaults), then
# prompts the user to install. First non-empty README line is used as the
# section title; remaining lines become info() lines under the header.
install_package() {
    local pkg="$1"

    # Apply a previously-recorded decision without re-prompting. This is the
    # frictionless path: only ask the user about packages they haven't seen.
    local decision; decision="$(decisions_get "$pkg")"
    case "$decision" in
        y)
            stow_package "$pkg"
            APPLIED_YES+=("$pkg")
            return
            ;;
        n)
            APPLIED_NO+=("$pkg")
            return
            ;;
    esac

    local readme="$DOTFILES_DIR/$pkg/README.md"
    local title="$pkg"
    local -a body=()

    if [[ -f "$readme" ]]; then
        local first_set=false line
        while IFS= read -r line || [[ -n "$line" ]]; do
            if ! $first_set; then
                [[ -z "$line" ]] && continue
                title="${line#\# }"
                first_set=true
                continue
            fi
            body+=("$line")
        done < "$readme"
    fi

    echo -e "\n${BOLD}━━━ $title ━━━${NC}"
    local line
    for line in "${body[@]}"; do
        [[ -z "$line" ]] && continue
        info "$line"
    done

    if ask "Install $pkg?"; then
        stow_package "$pkg"
        decisions_set "$pkg" "y"
        PROMPTED_YES+=("$pkg")
    else
        decisions_set "$pkg" "n"
        PROMPTED_NO+=("$pkg")
    fi
}

# ── Post-install fixups ──────────────────────────────────

# Guarantee $HOME/.local/bin is on PATH via the active ~/.bashrc so that tools
# installed there are found after `exec $SHELL`.
# The stowed bashrc already has this line, but users who skipped the bashrc
# stow or who have a custom ~/.bashrc won't get it otherwise.
ensure_local_bin_on_path() {
    local bashrc="$HOME/.bashrc"
    local line='export PATH="$HOME/.local/bin:$PATH"'

    if [[ ! -f "$bashrc" ]]; then
        info "Creating $bashrc with ~/.local/bin on PATH."
        echo "$line" > "$bashrc"
        return
    fi

    if grep -Fq '$HOME/.local/bin' "$bashrc" || grep -Fq "$HOME/.local/bin" "$bashrc"; then
        return
    fi

    info "Adding ~/.local/bin to PATH in $bashrc."
    printf '\n# Added by dotfiles stow-dotfiles.sh for user-local tools\n%s\n' "$line" >> "$bashrc"
}

# Point this repo's hooks at the tracked .githooks/ dir so post-merge fires
# on every `git pull` and re-stows any package whose contents changed upstream.
# Note: only fires on merge pulls — `git pull --rebase` will not trigger it.
enable_pull_hook() {
    echo -e "\n${BOLD}━━━ Auto-restow on git pull ━━━${NC}"
    if [[ ! -x "$DOTFILES_DIR/.githooks/post-merge" ]]; then
        warn "Missing executable .githooks/post-merge; skipping hook setup."
        return
    fi

    git -C "$DOTFILES_DIR" config core.hooksPath .githooks
    success "Enabled .githooks/post-merge. Future merge pulls will re-stow opted-in changed packages."
    info "Note: git pull --rebase does not run post-merge."
}

# ── Main ─────────────────────────────────────────────────

main() {
    echo -e "${BOLD}"
    echo "┌─────────────────────────────────────────┐"
    echo "│       Dotfiles Installer (Stow)          │"
    echo "│                                          │"
    echo "│  Discovers top-level stow packages       │"
    echo "│  such as bashrc, beets, claude, codex,   │"
    echo "│  nvim, oh-my-posh, and zellij.           │"
    echo "│                                          │"
    echo "│  Prerequisite:                           │"
    echo "│    ./install.sh               │"
    echo "│  (installs stow + all required tools)    │"
    echo "└─────────────────────────────────────────┘"
    echo -e "${NC}"
    info "Dotfiles directory: $DOTFILES_DIR"
    info "Home directory:     $HOME"
    echo ""

    if ! command_exists stow; then
        error "GNU Stow is not installed."
        error "Run ./install-tools-arch.sh first; it installs stow along with the other tools."
        exit 1
    fi

    local -a pkgs=()
    local _line
    while IFS= read -r _line; do
        pkgs+=("$_line")
    done < <(discover_packages)
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        warn "No stow packages found in $DOTFILES_DIR."
        warn "A stow package is a top-level directory whose children all start with '.'."
        exit 1
    fi

    info "Discovered packages: ${pkgs[*]}"

    # Tracking arrays populated by install_package. Globals (no `local`) so the
    # function can append to them.
    APPLIED_YES=()    # decision file said yes — re-stowed silently
    APPLIED_NO=()     # decision file said no — skipped silently
    PROMPTED_YES=()   # asked the user — they said yes
    PROMPTED_NO=()    # asked the user — they said no

    local pkg
    for pkg in "${pkgs[@]}"; do
        install_package "$pkg"
    done

    ensure_local_bin_on_path
    enable_pull_hook

    echo -e "\n${BOLD}━━━ Installation Complete ━━━${NC}"

    # Decisions summary — show what was applied vs newly recorded.
    if [[ ${#APPLIED_YES[@]} -gt 0 ]]; then
        info "Re-stowed per saved decision: ${APPLIED_YES[*]}"
    fi
    if [[ ${#APPLIED_NO[@]} -gt 0 ]]; then
        info "Skipped per saved decision:   ${APPLIED_NO[*]}"
    fi
    if [[ ${#PROMPTED_YES[@]} -gt 0 ]]; then
        info "Newly stowed (recorded yes):  ${PROMPTED_YES[*]}"
    fi
    if [[ ${#PROMPTED_NO[@]} -gt 0 ]]; then
        info "Newly declined (recorded no): ${PROMPTED_NO[*]}"
    fi
    info "Decisions saved to: $DECISIONS_FILE"
    info "  (delete the file to re-prompt for everything; edit a line to change a single answer)"
    echo ""

    info "Run 'exec \$SHELL' (or open a new terminal) to apply changes."
    info "Until then, ~/.local/bin tools may not be on PATH."
    info "Launch nvim after reload to trigger plugin installation."
    echo ""
    info "To unlink any package later, run from this directory:"
    for pkg in "${pkgs[@]}"; do
        info "  stow -D $pkg"
    done
    success "Done!"
}

main "$@"
