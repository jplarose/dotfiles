#!/usr/bin/env bash
set -euo pipefail

save_dir="$HOME/Pictures"
mkdir -p "$save_dir"
file="$save_dir/screenshot_$(date +%Y%m%d_%H%M%S).png"

notify_saved() {
    notify-send -a "Screen Capture" "Screenshot saved" "$file"
}

capture_screen() {
    grim "$file"
    notify_saved
}

capture_area() {
    local region
    region="$(slurp)" || exit 0
    [ -n "$region" ] || exit 0
    grim -g "$region" "$file"
    wl-copy --type image/png < "$file"
    notify-send -a "Screen Capture" "Screenshot saved and copied" "$file"
}

case "${1:-}" in
    --instant)
        capture_screen
        ;;
    --instant-area)
        capture_area
        ;;
    *)
        case "$(printf 'Screen\\nSelection' | rofi -dmenu -i -p 'Take screenshot')" in
            Screen) capture_screen ;;
            Selection) capture_area ;;
        esac
        ;;
esac
