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
    | .plugins.entries.codex |= (. // {})
    | .plugins.entries.codex |= if has("enabled") then . else . + { enabled: true } end
    | .plugins.entries["rtk-rewrite"] |= (. // {})
    | .plugins.entries["rtk-rewrite"] |= if has("enabled") then . else . + { enabled: true } end
  ' "$CONFIG_PATH" > "$tmpfile"
else
	jq -n '{
    plugins: {
      entries: {
        codex: { enabled: true },
        "rtk-rewrite": { enabled: true }
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
