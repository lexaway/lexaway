#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$SCRIPT_DIR/screenshot_config.yaml"

# --- Flags ---
CAPTURE=true
COMPOSE=true
DEVICE_FILTER=""
LANG_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --capture-only) COMPOSE=false; shift ;;
    --compose-only) CAPTURE=false; shift ;;
    --device) DEVICE_FILTER="$2"; shift 2 ;;
    --lang) LANG_FILTER="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

# --- Parse config (lightweight — no yq dependency) ---
parse_devices() {
  # Extracts device blocks from YAML. Each device yields: name|simulator_type|runtime
  awk '
    /^devices:/ { in_devices=1; next }
    /^[a-z]/ && !/^  / { in_devices=0 }
    in_devices && /- name:/ { name=$3 }
    in_devices && /simulator_type:/ { sim=$2 }
    in_devices && /runtime:/ { print name "|" sim "|" $2 }
  ' "$CONFIG"
}

parse_languages() {
  # Extracts the languages list from YAML
  awk '/^languages:/ { gsub(/.*\[|\].*/, ""); gsub(/, */, "\n"); print }' "$CONFIG"
}

# Build language list
if [[ -n "$LANG_FILTER" ]]; then
  LANGUAGES=("$LANG_FILTER")
else
  LANGUAGES=()
  while IFS= read -r l; do LANGUAGES+=("$l"); done < <(parse_languages)
fi

# --- Step 1: Capture ---
if $CAPTURE; then
  echo "==> Capturing screenshots"

  for lang in "${LANGUAGES[@]}"; do
    echo "=== Language: $lang ==="

    parse_devices | while IFS='|' read -r name sim_type runtime; do
      if [[ -n "$DEVICE_FILTER" && "$name" != "$DEVICE_FILTER" ]]; then
        continue
      fi

      echo "--- Device: $name ---"

      # Create simulator if it doesn't exist
      UDID=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime_id, devices in data['devices'].items():
    for d in devices:
        if d['name'] == '$name' and d.get('isAvailable', False):
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null || true)

      if [[ -z "$UDID" ]]; then
        echo "  Creating simulator $name..."
        UDID=$(xcrun simctl create "$name" "$sim_type" "$runtime")
        echo "  Created: $UDID"
      else
        echo "  Found existing: $UDID"
      fi

      # Boot
      STATE=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime_id, devices in data['devices'].items():
    for d in devices:
        if d['udid'] == '$UDID':
            print(d['state'])
            sys.exit(0)
")
      if [[ "$STATE" != "Booted" ]]; then
        echo "  Booting..."
        xcrun simctl boot "$UDID"
        xcrun simctl bootstatus "$UDID" -b
      fi

      # Run flutter drive
      echo "  Running integration test ($lang)..."
      cd "$PROJECT_DIR"
      SCREENSHOT_DEVICE_NAME="$name" SCREENSHOT_LANG="$lang" flutter drive \
        --driver=test_driver/integration_test.dart \
        --target=integration_test/screenshot_test.dart \
        --dart-define=SCREENSHOT_LANG="$lang" \
        -d "$UDID" \
        --no-pub

      # Shutdown
      echo "  Shutting down..."
      xcrun simctl shutdown "$UDID" 2>/dev/null || true

      echo "  Done: screenshots/raw/$lang/$name/"
    done
  done
fi

# --- Step 2: Compose ---
if $COMPOSE; then
  echo "==> Composing marketing assets"
  cd "$PROJECT_DIR"

  if [[ -n "$LANG_FILTER" ]]; then
    uv run --with pillow --with pyyaml "$SCRIPT_DIR/compose.py" --lang "$LANG_FILTER"
  else
    uv run --with pillow --with pyyaml "$SCRIPT_DIR/compose.py"
  fi
fi

echo "==> All done!"
