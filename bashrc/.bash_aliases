#######################################################
# Aliases
#######################################################

# Common Aliases
alias ls='ls -lah --color=auto'
alias grep='grep --color=auto'
alias rg='rg -. -M 100 -i --no-messages --color=auto'
alias yt='yt-dlp -f "bv*+ba/b" --merge-output-format mp4 --embed-metadata --embed-thumbnail --write-sub --write-auto-sub --sub-lang "en.*" --convert-subs srt'
alias cx='npm install -g @openai/codex'

# Custom Aliases
alias dev='cd "$DEV_DIRECTORY"'
alias ss='cbonsai -l -t 0.75 -i -w 10 -L 75 -M 12'
alias gnew='git fetch && git pull'
alias glog='git log --graph -n 20 --date=short --pretty=format:"%C(auto)%h%C(reset) %C(green)%ad%C(reset) %C(blue)%an%C(reset)%C(auto)%d%C(reset) %s %C(yellow)"'

alias vpnup='sudo wg-quick up Framework'
alias vpndown='sudo wg-quick down Framework'
alias vpnstatus='sudo wg show'

alias media='spf "$MEDIA_DIRECTORY" --config-file ~/.config/superfile/config-media.toml'
alias ymedia='yazi /mnt/nfs/media'

# Reset the waybar styling to pick up changes
alias waybset='killall -SIGUSR2 waybar'

# Zellij template chooser
alias zellij='zellij --layout "$ZELLIJ_LAYOUT_NAME"'

#######################################################
# Custom Functions
#######################################################

# Pass the machine-local library directory to beets when BEETS_DIR is set.
beet() {
  if [[ -n "${BEETS_DIR:-}" ]]; then
    command beet --directory "$BEETS_DIR" "$@"
  else
    command beet "$@"
  fi
}

# yt-dlp Playlist and Formatting
yta() {
  source "$HOME/.local/lib/yta/functions.bash" || return
  yta_run "$@"
}

#Combine common git commands into a single command
gitit() {
  local msg=""

  # Parse -m "message"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--message)
        shift
        msg="$1"
        ;;
      *)
        echo "Unknown argument: $1"
        return 1
        ;;
    esac
    shift
  done

  if [[ -z "$msg" ]]; then
    echo "Commit message required: gitit -m \"your message\""
    return 1
  fi

  git add . &&
  git commit -m "$msg" &&
  git push
}

# Git shortcuts for interactive Bash sessions.

__uconfig_git_rebase_main() {
    local current_branch
    local main_branch

    if [[ "$#" -ne 0 ]]; then
        printf '%s\n' 'rbmain: does not accept arguments' >&2
        return 2
    fi

    main_branch="$(command git config --get uconfig.mainbranch 2>/dev/null)" || main_branch="main"

    current_branch="$(command git branch --show-current)" || return

    if [[ -z "$current_branch" ]]; then
        printf '%s\n' 'rbmain: not on a branch' >&2
        return 1
    fi

    if [[ "$current_branch" == "$main_branch" ]]; then
        printf 'rbmain: already on %s\n' "$main_branch" >&2
        return 1
    fi

    command git switch "$main_branch" &&
        command git pull --ff-only origin "$main_branch" &&
        command git switch "$current_branch" &&
        command git rebase "$main_branch"
}

gitt() {
    case "${1-}" in
        ..)
            shift
            command git switch - "$@"
            ;;
        rbmain)
            shift
            __uconfig_git_rebase_main "$@"
            ;;
        *)
            command git "$@"
            ;;
    esac
}

g() {
    gitt "$@"
}

sub-check() {
    cd bhce || return
    command git status
    if [[ -n "$(command git status --porcelain)" ]]; then
        cd - >/dev/null
        return 1
    fi
    cd - >/dev/null &&
        command git add bhce &&
        command git rebase --continue
}
