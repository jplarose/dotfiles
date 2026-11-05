# Bash helpers for the yta workflow in ~/.bash_aliases.
# Source this file; it does not execute a download or change shell options.

yta_help() {
  cat <<'EOF'
Usage: yta [options] URL [URL...]
       yta --releases COLLECTION_URL [options]

Download audio as FLAC and import it through beets into BEETS_DIR by default.
Folders use Album/EP/Single prefixes when known; album tags use clean titles.
Unknown release types use NA - TITLE. Beets applies its own paths on import.
A final summary lists completed, partial, failed, and already-downloaded releases.

yta options:
  -h, --help                  Show this help and exit without downloading.
  -c, --chapters              Split each video's chapters into separate tracks
                              and add FLAC metadata and cover art.
  -n, --no-import             Copy files into BEETS_DIR without a beets import.
  -r, --releases URL          Discover albums, EPs, and singles from a YouTube
                              Music collection; implies --no-import. URL must
                              follow the flag as a separate argument and use
                              https://music.youtube.com/browse/MPAD...
  -s, --singles URL           Alias for --releases; includes every release type.

Cookie options (built into yt-dlp; forwarded in every download mode):
  --cookies FILE             Read/write a Netscape-format cookie file.
                              Example: --cookies "$HOME/cookies.txt"
  --cookies-from-browser SPEC Extract cookies from a browser, e.g. firefox or
                              chrome. Optional profile/keyring/container syntax:
                              BROWSER[+KEYRING][:PROFILE][::CONTAINER]
                              Example: --cookies-from-browser 'firefox:default'
  Cookies apply to downloads, including discovered releases. Collection
  discovery itself fetches public pages without cookies or other yt-dlp options.

Other arguments pass through to yt-dlp. Run `yt-dlp --help` for its full list.
Use separate short flags (-c -n), and quote URLs and values containing spaces.
Set BEETS_DIR before downloading, e.g. BEETS_DIR="$HOME/Music".

Examples:
  yta 'https://www.youtube.com/watch?v=VIDEO_ID'
  yta -c -n --cookies "$HOME/cookies.txt" 'https://youtu.be/VIDEO_ID'
  yta --cookies-from-browser firefox --playlist-items '1:5' 'PLAYLIST_URL'
  yta -r 'https://music.youtube.com/browse/MPAD...' --cookies-from-browser chrome
EOF
}

yta_validate_config() {
  if [[ -z "${BEETS_DIR:-}" ]]; then
    echo "BEETS_DIR is not set; refusing to import into beets' default ~/Music directory" >&2
    return 1
  fi
}

# Only stdout contains URLs, so the caller can collect them into an array.
yta_discover_releases() {
  python3 "$HOME/.local/lib/yta/discover_singles.py" "$@"
}

yta_prepare_run() {
  yta_validate_config || return
  local staging_parent="$BEETS_DIR/_staging"
  mkdir -p "$staging_parent" "$HOME/.config/yt-dlp" || return 1
  mktemp -d "$staging_parent/ytplxflac.XXXXXXXX"
}

# Shared options and partial-download handling for both download modes.
_yta_download() {
  local run_dir="$1"
  shift
  local ytdlp_status=0
  local ytdlp_opts=(
    -f "bestaudio[acodec=opus]/bestaudio/best"
    -x --audio-format flac --audio-quality 0
    --ignore-errors
    --no-abort-on-error
    --download-archive "$HOME/.config/yt-dlp/plex-audio-archive.txt"
  )

  yt-dlp "${ytdlp_opts[@]}" "$@" || ytdlp_status=$?

  if ! find "$run_dir" -type f | grep -q .; then
    echo "yt-dlp downloaded no files" >&2
    rm -rf "$run_dir"
    return 1
  fi

  if [ "$ytdlp_status" -ne 0 ]; then
    echo "yt-dlp reported some errors, but downloaded files were kept; continuing with downloaded files" >&2
  fi
  return 0
}

yta_download_chapters() {
  local run_dir="$1"
  shift
  local yta_metadata_opts=()
  yta_set_metadata_options
  _yta_download "$run_dir" \
    "${yta_metadata_opts[@]}" \
    --split-chapters \
    --write-thumbnail --convert-thumbnails jpg \
    -o "$run_dir/_source/%(title)s [%(id)s].%(ext)s" \
    -o "chapter:$run_dir/%(uploader|Unknown Artist)s/%(yta_type|NA)s - %(yta_album,album,playlist_title,title,id|Unknown Release)s/%(section_number)02d - %(section_title)s.%(ext)s" \
    -o "thumbnail:$run_dir/%(uploader|Unknown Artist)s/%(yta_type|NA)s - %(yta_album,album,playlist_title,title,id|Unknown Release)s/cover.%(ext)s" "$@"
}

yta_download_tracks() {
  local run_dir="$1"
  shift
  local yta_metadata_opts=()
  yta_set_metadata_options
  _yta_download "$run_dir" \
    "${yta_metadata_opts[@]}" \
    --embed-metadata \
    --embed-thumbnail \
    --parse-metadata "%(uploader|Unknown Artist)s:%(meta_artist)s" \
    --parse-metadata "%(uploader|Unknown Artist)s:%(meta_album_artist)s" \
    --parse-metadata "%(yta_album)s:%(meta_album)s" \
    --parse-metadata "%(playlist_index|0)s:%(meta_track)s" \
    -o "$run_dir/%(uploader|Unknown Artist)s/%(yta_type|NA)s - %(yta_album,album,playlist_title,title,id|Unknown Release)s/%(playlist_index|0)02d - %(title)s.%(ext)s" "$@"
}

yta_set_metadata_options() {
  # Each public download helper declares this array locally. Initialize it
  # there so callers with an older yta function loaded still get metadata.
  # Replacement values are literal metadata, not templates. Escape backslashes
  # so a title containing e.g. \1 cannot become a regex group reference.
  yta_metadata_opts=(
    --parse-metadata '%(playlist_title,title,id|Unknown Release)s:%(yta_playlist)s'
    --replace-in-metadata yta_playlist '^(Album|EP|Single) - ' ''
    --parse-metadata '%(album,yta_playlist)s:%(yta_album)s'
    --parse-metadata '%(album_type|)s:%(yta_type)s'
    --replace-in-metadata yta_type '^(?!(?i:album|ep|single)$).*$' NA
    --replace-in-metadata yta_type '(?i)^album$' Album
    --replace-in-metadata yta_type '(?i)^ep$' EP
    --replace-in-metadata yta_type '(?i)^single$' Single
  )
  if [[ -n "${yta_release_title:-}" ]]; then
    yta_metadata_opts+=(--replace-in-metadata yta_album '(?s)^.*$' "${yta_release_title//\\/\\\\}")
  fi
  if [[ -n "${yta_release_type:-}" ]]; then
    # Interpret an empty input with .* so the field exists even without a
    # direct-url album_type, then set the known collection label.
    yta_metadata_opts+=(--parse-metadata '%(yta_type|)s:(?P<yta_type>.*)'
      --replace-in-metadata yta_type '(?s)^.*$' "$yta_release_type")
  fi
  if [[ "${yta_release_year:-}" =~ ^(19|20)[0-9]{2}$ ]]; then
    yta_metadata_opts+=(--parse-metadata "${yta_release_year}:%(meta_date)s")
  fi
}

yta_download_and_process() {
  local run_dir="$1"
  shift
  if "$split_chapters"; then
    yta_download_chapters "$run_dir" "$@" || return
    yta_process_chapters "$run_dir"
  else
    yta_download_tracks "$run_dir" "$@"
  fi
}

yta_process_chapters() {
  local run_dir="$1"
  rm -rf "$run_dir/_source" || return

  # Manually embed metadata/art into split-chapter files, since yt-dlp's
  # built-in --embed-metadata/--embed-thumbnail unreliably rename files
  # when combined with --split-chapters. Audio is re-encoded through the
  # reference `flac` tool (not ffmpeg's own FLAC muxer) because ffmpeg
  # writes an incorrect STREAMINFO total-samples value on these files even
  # on a full decode/re-encode, causing players like Plex to report the
  # original video's full length instead of the trimmed clip's actual length.
  local album_dir artist album cover track title flac_file tmp
  while IFS= read -r -d '' cover; do
    album_dir="$(dirname "$cover")"
    artist="$(basename "$(dirname "$album_dir")")"
    album="$(basename "$album_dir")"
    # The directory includes a release-type prefix; the album tag does not.
    case "$album" in
      'Album - '*|'EP - '*|'Single - '*|'NA - '*) album="${album#* - }" ;;
    esac
    while IFS= read -r -d '' flac_file; do
      track="$(basename "$flac_file" .flac | cut -d' ' -f1)"
      title="$(basename "$flac_file" .flac | cut -d' ' -f3-)"
      tmp="${flac_file}.tmp"
      (set -o pipefail
        ffmpeg -nostdin -loglevel error -i "$flac_file" -map 0:a -map_chapters -1 -f wav - < /dev/null \
          | flac --best --silent -f -o "$tmp" -
      ) || return
      metaflac \
        --set-tag="ARTIST=$artist" \
        --set-tag="ALBUMARTIST=$artist" \
        --set-tag="ALBUM=$album" \
        --set-tag="TRACKNUMBER=$track" \
        --set-tag="TITLE=$title" \
        "$tmp" || return
      metaflac --import-picture-from="3||||$cover" "$tmp" || return
      if [[ "${yta_release_year:-}" =~ ^(19|20)[0-9]{2}$ ]]; then
        metaflac --set-tag="DATE=$yta_release_year" "$tmp" || return
      fi
      mv "$tmp" "$flac_file" || return
    done < <(find "$album_dir" -maxdepth 1 -name '*.flac' -print0)
  done < <(find "$run_dir" -name 'cover.jpg' -print0)
}

yta_copy_to_library() {
  local run_dir="$1"
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
}

yta_import_to_beets() {
  local run_dir="$1"
  local beet_status=0
  command beet --directory "$BEETS_DIR" import "$run_dir" || beet_status=$?

  if [ "$beet_status" -eq 0 ]; then
    rm -rf "$run_dir"
  else
    echo "beets import failed; keeping staging directory: $run_dir" >&2
  fi

  return "$beet_status"
}

yta_finish_release() {
  local run_dir="$1"
  shift
  yta_download_and_process "$run_dir" "$@" || return
  if "$skip_import"; then
    yta_copy_to_library "$run_dir"
  else
    yta_import_to_beets "$run_dir"
  fi
}

# Keep live output while collecting diagnostics outside the staging directory,
# which is removed on successful copies/imports. The pipeline waits for tee
# before reading the log, so the final error cannot race the summary.
yta_report_release() {
  local label="$1" run_dir="$2"
  shift 2
  local log_file status detail outcome
  if ! log_file="$(mktemp "${TMPDIR:-/tmp}/yta-result.XXXXXXXX")"; then
    yta_summary_labels+=("$label")
    yta_summary_outcomes+=(failed)
    yta_summary_details+=("Could not create a temporary diagnostic log; staging directory: $run_dir")
    return 1
  fi
  yta_finish_release "$run_dir" "$@" 2>&1 | tee "$log_file" >&2
  status=${PIPESTATUS[0]}
  detail="$(sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g; s/\r/\n/g' "$log_file" |
    awk '/(^|[[:space:]])ERROR:|^failed to |^beets import failed;|^yt-dlp downloaded no files$|^yt-dlp reported some errors/')"
  if [[ "$status" -eq 0 ]]; then
    if [[ -n "$detail" ]]; then
      outcome=partial
    else
      outcome=success
    fi
  elif grep -Eq 'already been recorded in the archive|has already been downloaded' "$log_file" &&
       ! grep -q 'ERROR:' "$log_file" && [[ ! -d "$run_dir" ]]; then
    outcome=skipped
    detail="Already downloaded; no new files."
    status=0
  else
    outcome=failed
    if [[ -z "$detail" ]]; then
      detail="$(tail -n 5 "$log_file")"
      detail="${detail:-Command exited with status $status.}"
    fi
  fi
  rm -f "$log_file"
  yta_summary_labels+=("$label")
  yta_summary_outcomes+=("$outcome")
  yta_summary_details+=("$detail")
  return "$status"
}

yta_print_summary() {
  local outcome heading index count line
  printf '\n========== yta run summary ==========\n'
  for outcome in success partial failed skipped; do
    case "$outcome" in
      success) heading='Successfully downloaded and saved' ;;
      partial) heading='Partial downloads saved (errors occurred)' ;;
      failed) heading='Failed' ;;
      skipped) heading='Skipped (already downloaded)' ;;
    esac
    count=0
    for index in "${!yta_summary_outcomes[@]}"; do
      [[ "${yta_summary_outcomes[index]}" == "$outcome" ]] && count=$((count + 1))
    done
    printf '\n%s (%d):\n' "$heading" "$count"
    for index in "${!yta_summary_outcomes[@]}"; do
      [[ "${yta_summary_outcomes[index]}" == "$outcome" ]] || continue
      printf '  - %s\n' "${yta_summary_labels[index]}"
      if [[ "$outcome" == partial || "$outcome" == failed ]]; then
        while IFS= read -r line; do
          printf '      %s\n' "$line"
        done <<< "${yta_summary_details[index]}"
      fi
    done
  done
  printf '\n'
}

# Reloaded by the small yta entry point on every invocation.
yta_run() {

  local split_chapters=false
  local skip_import=false
  local releases_page=""
  local release_urls
  local releases=()
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) yta_help; return 0 ;;
      -c|--chapters)  split_chapters=true ;;
      -n|--no-import) skip_import=true ;;
      --cookies|--cookies-from-browser)
        if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
          echo "yta: $1 requires a value; see yta --help" >&2
          return 2
        fi
        args+=("$1" "$2")
        shift
        ;;
      -r|--releases|-s|--singles)
        if [[ $# -lt 2 || -z "$2" || "$2" == -* || -n "$releases_page" ]]; then
          echo 'Usage: yta --releases YOUTUBE_MUSIC_COLLECTION_PAGE [options]' >&2
          return 2
        fi
        releases_page="$2"
        shift
        ;;
      *) args+=("$1") ;;
    esac
    shift
  done

  yta_validate_config || return
  if [[ -n "$releases_page" ]]; then
    skip_import=true
    release_urls="$(yta_discover_releases --tsv "$releases_page")" || return
    mapfile -t releases <<< "$release_urls"
  fi

  local run_dir
  local yta_summary_labels=() yta_summary_outcomes=() yta_summary_details=()

  if [[ -n "$releases_page" ]]; then
    local release release_url yta_release_type yta_release_title yta_release_year
    local download_status=0 label
    for release in "${releases[@]}"; do
      IFS=$'\t' read -r release_url yta_release_type yta_release_title yta_release_year <<< "$release"
      [[ "$yta_release_type" == '-' ]] && yta_release_type=""
      [[ "$yta_release_title" == '-' ]] && yta_release_title=""
      [[ "$yta_release_year" == '-' ]] && yta_release_year=""
      printf 'yta: %s - %s (year: %s)\n' "${yta_release_type:-NA}" \
        "${yta_release_title:-$release_url}" "${yta_release_year:-unknown}" >&2
      if [[ -z "$yta_release_type" ]]; then
        printf 'yta: collection response has no recognized release type for %s\n' "$release_url" >&2
      fi
      # Each release needs its own metadata overrides and staging directory.
      label="${yta_release_type:-NA} - ${yta_release_title:-$release_url}"
      [[ -n "$yta_release_year" ]] && label+=" ($yta_release_year)"
      if ! run_dir="$(yta_prepare_run)"; then
        yta_summary_labels+=("$label")
        yta_summary_outcomes+=(failed)
        yta_summary_details+=("Could not create staging directory under $BEETS_DIR/_staging.")
        download_status=1
        continue
      fi
      if yta_report_release "$label" "$run_dir" "${args[@]}" "$release_url"; then
        :
      else
        download_status=$?
      fi
    done
    yta_print_summary
    return "$download_status"
  else
    run_dir="$(yta_prepare_run)" || return
    local label='Requested release' arg status=0
    # Direct URLs may be playlists or chaptered releases; summarize the request
    # as one batch rather than pretending each downloaded track is a release.
    for arg in "${args[@]}"; do
      [[ "$arg" == https://* || "$arg" == http://* ]] && label="$arg"
    done
    yta_report_release "$label" "$run_dir" "${args[@]}" || status=$?
    yta_print_summary
    return "$status"
  fi
}

