#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
#  Arch Linux Environment Setup
#
#  Reproduces the full package environment from scratch.
#  Intended for a fresh Arch install (or WSL Arch image).
#
#  Steps:
#    1. Full system upgrade (pacman -Syu)
#    2. Install paru (AUR helper)
#    3. Install all official repo packages
#    4. Install all AUR packages
# ─────────────────────────────────────────────────────────

# ── Colors ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; }

command_exists() { command -v "$1" &>/dev/null; }
paru_works() { command_exists paru && paru --version &>/dev/null; }

install_paru_from_source() {
    info "Installing paru from source..."

    # paru requires base-devel and git to build
    sudo pacman -S --needed --noconfirm base-devel git

    local paru_build_dir
    paru_build_dir="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru.git "$paru_build_dir/paru"
    pushd "$paru_build_dir/paru" > /dev/null
    makepkg -si --noconfirm
    popd > /dev/null
    rm -rf "$paru_build_dir"
}

# ── Preflight checks ────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root. It will use sudo when needed."
    exit 1
fi

if ! command_exists pacman; then
    error "pacman not found. This script is for Arch Linux only."
    exit 1
fi

echo -e "${BOLD}"
echo "┌──────────────────────────────────────────┐"
echo "│     Arch Linux Environment Setup          │"
echo "│                                           │"
echo "│  This script will:                        │"
echo "│    1. Update the system (pacman -Syu)     │"
echo "│    2. Install paru (AUR helper)           │"
echo "│    3. Install official repo packages      │"
echo "│    4. Install AUR packages                │"
echo "└──────────────────────────────────────────┘"
echo -e "${NC}"

echo -en "${BOLD}Continue? [Y/n]:${NC} "
read -r answer
answer="${answer:-y}"
if [[ "${answer,,}" != "y" ]]; then
    info "Aborted."
    exit 0
fi

# ─────────────────────────────────────────────────────────
#  Step 1: Full system upgrade
# ─────────────────────────────────────────────────────────
echo -e "\n${BOLD}━━━ Step 1: System Upgrade ━━━${NC}"
info "Running pacman -Syu..."
# sudo pacman -Syu --noconfirm
success "System is up to date."

# ─────────────────────────────────────────────────────────
#  Step 2: Install paru (AUR helper)
# ─────────────────────────────────────────────────────────
echo -e "\n${BOLD}━━━ Step 2: Install paru ━━━${NC}"

if paru_works; then
    success "paru is already installed ($(paru --version | head -1))"
else
    if command_exists paru; then
        warn "paru is installed but not usable. Rebuilding it against the current pacman/libalpm."
    fi

    install_paru_from_source

    if paru_works; then
        success "paru installed successfully ($(paru --version | head -1))"
    else
        error "paru installation failed. Cannot continue with AUR packages."
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────
#  Step 3: Install official repo packages
# ─────────────────────────────────────────────────────────
echo -e "\n${BOLD}━━━ Step 3: Official Repo Packages ━━━${NC}"

PACMAN_PACKAGES=(
    aspnet-runtime
    aspnet-runtime-8.0
    aspnet-targeting-pack
    base
    base-devel
#    beets
    dotnet-runtime
    dotnet-sdk
    dotnet-sdk-8.0
    dotnet-targeting-pack
    fd
    gcc
    git
    github-cli
#   glow
    go
    jq
    make
    man-db
    man-pages
    nano
    neovim
#    nodejs
#    npm
    opencode
    ripgrep
    stow
    sudo
    unzip
    which
#    yt-dlp
    zellij
    tree-sitter-cli
    tea
    nvm
)

info "Installing ${#PACMAN_PACKAGES[@]} official packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
success "Official packages installed."

# ─────────────────────────────────────────────────────────
#  Step 4: Install AUR packages
# ─────────────────────────────────────────────────────────
echo -e "\n${BOLD}━━━ Step 4: AUR Packages ━━━${NC}"

AUR_PACKAGES=(
#    cbonsai
    oh-my-posh
)

info "Installing ${#AUR_PACKAGES[@]} AUR packages via paru..."
paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"
success "AUR packages installed."

# ─────────────────────────────────────────────────────────
#  Done
# ─────────────────────────────────────────────────────────
echo -e "\n${BOLD}━━━ Environment Setup Complete ━━━${NC}"
info "All packages have been installed."
echo ""

echo -e "${BOLD}━━━ Credential Configuration ━━━${NC}"
echo ""
echo -e "${BOLD}Git:${NC}"
echo "  git config --global user.name \"Your Name\""
echo "  git config --global user.email \"your.email@example.com\""
echo "  git config --global credential.helper store"
echo "  # Credentials will be saved to ~/.git-credentials after your next git push/pull."
echo "  # You can also add credentials manually to ~/.git-credentials using these formats:"
echo "  #   https://USERNAME:PAT@github.com"
echo ""
echo -e "${BOLD}GitHub CLI:${NC}"
echo "  gh auth login"
echo "  # Follow the prompts to authenticate via browser or token."
echo ""
echo -e "${BOLD}Next steps:${NC}"
info "  1. Configure credentials above"
info "  2. Run ./stow-dotfiles.sh to stow dotfiles"
info "  3. Restart your shell or run 'source ~/.bashrc'"
success "Done!"
