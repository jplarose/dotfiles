#!/usr/bin/env bash
# Script by https://github.com/anshifmonz

set -Eeuo pipefail

SLURP_TIMEOUT=10
DEPS=(grim slurp magick tesseract wl-copy timeout)

die() { echo "Error: $*" >&2; exit 1; }

# Check dependencies
check_deps() {
  local missing_dependencies=()
  for dep in "${DEPS[@]}"; do command -v "$dep" >/dev/null 2>&1 || missing_dependencies+=("$dep"); done
  if (( ${#missing_dependencies[@]} > 0 )); then
    die "Missing dependencies: ${missing_dependencies[*]}"
  fi
}

check_deps

rofi_cmd() {
    rofi -dmenu -replace -i -no-show-icons -l 3 -width 30 -p "Select the OCR language"
}

mapfile -t OCR_LANGUAGES < <(tesseract --list-langs 2>/dev/null | tail -n +2 | awk 'NF && $0 != "osd"')
(( ${#OCR_LANGUAGES[@]} > 0 )) || die "No OCR languages are installed"

OCR_LANGUAGE="${OCR_LANGUAGES[0]}"
for language in "${OCR_LANGUAGES[@]}"; do
    if [[ "$language" == "eng" ]]; then
        OCR_LANGUAGE="eng"
        break
    fi
done

if (( ${#OCR_LANGUAGES[@]} > 1 )); then
    selected_language="$(printf '%s\n' "${OCR_LANGUAGES[@]}" | rofi_cmd)"
    [[ -n "$selected_language" ]] && OCR_LANGUAGE="$selected_language"
    sleep 0.5 || true
fi

REGION=$(timeout "$SLURP_TIMEOUT" slurp -b "#00000080" -c "#888888ff" -w 1) || die "No region selected (timeout or cancelled)"
[[ -z "$REGION" ]] && die "No region selected"

grim -g "$REGION" - \
  | magick - -colorspace Gray -normalize -contrast-stretch 2% -sharpen 0x1.0 -resize 200% png:- \
  | tesseract - stdout -l "$OCR_LANGUAGE" --psm 6 \
  | wl-copy \
  || die "Failed to capture or process text"
