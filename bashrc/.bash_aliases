#######################################################
# Aliases
#######################################################

# Common Aliases
alias ls='ls -la --color=auto'
alias grep='grep --color=auto'
alias rg='rg -. -M 100 -i --no-messages --color=auto'
alias yt='yt-dlp -f "bv*+ba/b" --merge-output-format mp4 --embed-metadata --embed-thumbnail'

# Custom Aliases
alias dev='cd "$DEV_DIRECTORY"'
alias ss='cbonsai -l -t 0.75 -i -w 10 -L 75 -M 12'
alias glog='git log --oneline -n 20 --graph'
alias gnew='git fetch && git pull'

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


