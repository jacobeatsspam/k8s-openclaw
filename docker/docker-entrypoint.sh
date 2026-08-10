#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-${HOME}/.openclaw}"
CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-${OPENCLAW_HOME}/openclaw.json}"

mkdir -p "${OPENCLAW_HOME}" "$(dirname "${CONFIG_PATH}")"

tmpfile="$(mktemp)"
cleanup() {
  rm -f "$tmpfile"
}
trap cleanup EXIT

if [[ -f "$CONFIG_PATH" ]]; then
  jq '
    .plugins |= (. // {})
    | .plugins.entries |= (. // {})
    | .plugins.entries.diffs |= (. // {})
    | .plugins.entries.diffs |= if has("enabled") then . else . + { enabled: true } end
    | .plugins.entries.lobster |= (. // {})
    | .plugins.entries.lobster |= if has("enabled") then . else . + { enabled: true } end
    | .plugins.entries["google-meet"] |= (. // {})
    | .plugins.entries["google-meet"] |= if has("enabled") then . else . + { enabled: true } end
    | .plugins.entries["rtk-rewrite"] |= (. // {})
    | .plugins.entries["rtk-rewrite"] |= if has("enabled") then . else . + { enabled: true } end
    | .plugins.entries.codex |= (. // {})
    | .plugins.entries.codex |= if has("enabled") then . else . + { enabled: true } end
    | .plugins.entries.anthropic |= (. // {})
    | .plugins.entries.anthropic |= if has("enabled") then . else . + { enabled: true } end
  ' "$CONFIG_PATH" > "$tmpfile"
else
  jq -n '{
    plugins: {
      entries: {
        diffs: { enabled: true },
        lobster: { enabled: true },
        "google-meet": { enabled: true },
        "rtk-rewrite": { enabled: true },
        codex: { enabled: true },
        anthropic: { enabled: true }
      }
    }
  }' > "$tmpfile"
fi

mv "$tmpfile" "$CONFIG_PATH"

# if thrown flags immediately,
# assume they want to run the blockchain daemon
if [ "$(printf '%s' "$1" | cut -c 1)" = '-' ]; then
	set -- tini -s -- node openclaw.mjs gateway "$@"
fi

exec "$@"
