#######################################################
# Aliases
#######################################################

# Common Aliases
alias ls='ls -lah --color=auto'
alias grep='grep --color=auto'
alias rg='rg -. -M 100 -i --no-messages --color=auto'
alias yt='yt-dlp -f "bv*+ba/b" --merge-output-format mp4 --embed-metadata --embed-thumbnail --write-sub --write-auto-sub --sub-lang "en.*" --convert-subs srt'

# Custom Aliases
alias dev='cd "$DEV_DIRECTORY"'
alias ss='cbonsai -l -t 0.75 -i -w 10 -L 75 -M 12'
alias gnew='git fetch && git pull'
alias glog='git log --graph -n 20 --date=short --pretty=format:"%C(auto)%h%C(reset) %C(green)%ad%C(reset) %C(blue)%an%C(reset)%C(auto)%d%C(reset) %s %C(yellow)"'

alias vpnup='sudo wg-quick up Framework'
alias vpndown='sudo wg-quick down Framework'
alias vpnstatus='sudo wg show'

# Reset the waybar styling to pick up changes
alias waybset='killall -SIGUSR2 waybar'

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
  if [[ -z "${BEETS_DIR:-}" ]]; then
    echo "BEETS_DIR is not set; refusing to import into beets' default ~/Music directory" >&2
    return 1
  fi

  local split_chapters=false
  local skip_beets=false
  local args=()
  for arg in "$@"; do
    case "$arg" in
      -c|--chapters)
        split_chapters=true
        ;;
      -n|--no-import)
        skip_beets=true
        ;;
      *)
        args+=("$arg")
        ;;
    esac
  done
  
  local staging_parent="$BEETS_DIR/_staging"
  local staging_base="$staging_parent/ytplxflac"
  local run_dir
  local ytdlp_status
  local beet_status

  mkdir -p "$staging_parent" "$HOME/.config/yt-dlp" || return 1
  run_dir="$(mktemp -d "$staging_base.XXXXXXXX")" || return 1

  local ytdlp_opts=(
    -f "bestaudio[acodec=opus]/bestaudio/best"
    -x --audio-format flac --audio-quality 0
    --ignore-errors
    --no-abort-on-error
    --download-archive "$HOME/.config/yt-dlp/plex-audio-archive.txt"
  )

  if [ "$split_chapters" = true ]; then
    ytdlp_opts+=(
      --split-chapters
      --write-thumbnail --convert-thumbnails jpg
      -o "$run_dir/_source/%(title)s [%(id)s].%(ext)s"
      -o "chapter:$run_dir/%(uploader|Unknown Artist)s/%(title)s/%(section_number)02d - %(section_title)s.%(ext)s"
      -o "thumbnail:$run_dir/%(uploader|Unknown Artist)s/%(title)s/cover.%(ext)s"
    )
  else
    ytdlp_opts+=(
      --embed-metadata
      --embed-thumbnail 
      --parse-metadata "%(uploader|Unknown Artist)s:%(meta_artist)s"
      --parse-metadata "%(uploader|Unknown Artist)s:%(meta_album_artist)s"
      --parse-metadata "%(playlist_title|Singles)s:%(meta_album)s"
      --parse-metadata "%(playlist_index|0)s:%(meta_track)s"
      -o "$run_dir/%(uploader|Unknown Artist)s/%(playlist_title|Singles)s/%(playlist_index|0)02d - %(title)s.%(ext)s"
    )
  fi

  yt-dlp "${ytdlp_opts[@]}" "${args[@]}"

  ytdlp_status=$?

  if ! find "$run_dir" -type f | grep -q .; then
    echo "yt-dlp downloaded no files" >&2
    rm -rf "$run_dir"
    return 1
  fi

  if [ "$ytdlp_status" -ne 0 ]; then
    echo "yt-dlp reported some errors, but downloaded files were kept; continuing to beets" >&2
  fi

  if [ "$split_chapters" = true ]; then
    rm -rf "$run_dir/_source"
  fi

  # Manually embed metadata/art into split-chapter files, since yt-dlp's
  # built-in --embed-metadata/--embed-thumbnail unreliably rename files
  # when combined with --split-chapters. Audio is re-encoded through the
  # reference `flac` tool (not ffmpeg's own FLAC muxer) because ffmpeg
  # writes an incorrect STREAMINFO total-samples value on these files even
  # on a full decode/re-encode, causing players like Plex to report the
  # original video's full length instead of the trimmed clip's actual length.
  if [ "$split_chapters" = true ]; then
    local album_dir artist album cover track title flac_file tmp
    while IFS= read -r -d '' cover; do
      album_dir="$(dirname "$cover")"
      artist="$(basename "$(dirname "$album_dir")")"
      album="$(basename "$album_dir")"
      while IFS= read -r -d '' flac_file; do
        track="$(basename "$flac_file" .flac | cut -d' ' -f1)"
        title="$(basename "$flac_file" .flac | cut -d' ' -f3-)"
        tmp="${flac_file}.tmp"
        ffmpeg -nostdin -loglevel error -i "$flac_file" -map 0:a -map_chapters -1 -f wav - < /dev/null \
          | flac --best --silent -f -o "$tmp" -
        metaflac \
          --set-tag="ARTIST=$artist" \
          --set-tag="ALBUMARTIST=$artist" \
          --set-tag="ALBUM=$album" \
          --set-tag="TRACKNUMBER=$track" \
          --set-tag="TITLE=$title" \
          "$tmp"
        metaflac --import-picture-from="3||||$cover" "$tmp"
        mv "$tmp" "$flac_file"
      done < <(find "$album_dir" -maxdepth 1 -name '*.flac' -print0)
    done < <(find "$run_dir" -name 'cover.jpg' -print0)
  fi

  if [ "$skip_beets" = true ]; then
    mkdir -p "$BEETS_DIR" || return 1
    if command -v rsync >/dev/null 2>&1; then
      rsync -a "$run_dir"/ "$BEETS_DIR"/
    else
      cp -a "$run_dir"/. "$BEETS_DIR"/
    fi
    local move_status=$?
    if [ "$move_status" -eq 0 ]; then
      rm -rf "$run_dir"
      echo "Files moved to: $BEETS_DIR" >&2
    else
      echo "failed to move files into $BEETS_DIR; keeping staging directory: $run_dir" >&2
    fi
    return "$move_status"
  fi

  command beet --directory "$BEETS_DIR" import "$run_dir"
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
