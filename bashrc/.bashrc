#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#######################################################
# Aliases
#######################################################

# Common Aliases
alias ls='ls -la --color=auto'
alias grep='grep --color=auto'
alias rg='rg -. -M 100 -i --no-messages --color=auto'
alias yt='yt-dlp -f "bv*+ba/b" --merge-output-format mp4 --embed-metadata --embed-thumbnail'

# Custom Aliases
alias dev='cd /home/jlarose/Dev'

#######################################################
# Common Settings Tweaks
#######################################################
export EDITOR=nvim

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500

# Don't put duplicate lines in the history and do not add lines that start with a space
export HISTCONTROL=erasedups:ignoredups:ignorespace

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

PS1='[\u@\h \W]\$ '

# Path
export PATH="$HOME/.local/bin:$PATH"

#######################################################
# Custom Functions
#######################################################

# yt-dlp Playlist and Formatting
yta() {
  local staging_base="$HOME/Music/_staging/ytplxflac"
  local run_dir
  run_dir="$(mktemp -d "$staging_base.XXXXXXXX")" || return 1

  mkdir -p "$run_dir" "$HOME/.config/yt-dlp" || return 1

  yt-dlp \
    -f "bestaudio[acodec=opus]/bestaudio/best" \
    -x --audio-format flac --audio-quality 0 \
    --embed-metadata \
    --embed-thumbnail \
	--ignore-errors \
	--no-abort-on-error \
    --download-archive "$HOME/.config/yt-dlp/plex-audio-archive.txt" \
    --parse-metadata "%(uploader|Unknown Artist)s:%(meta_artist)s" \
    --parse-metadata "%(uploader|Unknown Artist)s:%(meta_album_artist)s" \
    --parse-metadata "%(playlist_title|Singles)s:%(meta_album)s" \
    --parse-metadata "%(playlist_index|0)s:%(meta_track)s" \
    -o "$run_dir/%(uploader|Unknown Artist)s/%(playlist_title|Singles)s/%(playlist_index|0)02d - %(title)s.%(ext)s" \
    "$@"
	ytdlp_status=$?

  if ! find "$run_dir" -type f | grep -q .; then
    echo "yt-dlp downloaded no files" >&2
    rm -rf "$run_dir"
    return 1
  fi

  if [ "$ytdlp_status" -ne 0 ]; then
    echo "yt-dlp reported some errors, but downloaded files were kept; continuing to beets" >&2
  fi

  beet import "$run_dir"
  beet_status=$?

  if [ "$beet_status" -eq 0 ]; then
    rm -rf "$run_dir"
  else
    echo "beets import failed; keeping staging directory: $run_dir" >&2
  fi

  return "$beet_status"
}

#Automatically do an ls after each cd
 cd ()
 {
 	if [ -n "$1" ]; then
 		builtin cd "$@" && \ls --color=always
 	else
 		builtin cd ~ && \ls --color=always
 	fi
 }

eval "$(oh-my-posh init bash --config ~/.config/omp/takuya.omp.json)"

# Load machine-local aliases last so they override repo defaults
if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi
