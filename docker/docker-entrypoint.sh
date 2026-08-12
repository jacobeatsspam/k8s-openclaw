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

# Configure kubectl for in-cluster service account access
if [ -n "${KUBERNETES_SERVICE_HOST:-}" ] && [ -n "${KUBERNETES_SERVICE_PORT:-}" ] \
  && [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ] \
  && [ -f /var/run/secrets/kubernetes.io/serviceaccount/ca.crt ] \
  && [ -f /var/run/secrets/kubernetes.io/serviceaccount/namespace ]; then

  SA_DIR=/var/run/secrets/kubernetes.io/serviceaccount
  KCFG=/tmp/incluster-kubeconfig
  API_SERVER="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
  TOKEN="$(cat "$SA_DIR/token")"
  NAMESPACE="$(cat "$SA_DIR/namespace")"

  kubectl config --kubeconfig="$KCFG" set-cluster incluster \
    --server="$API_SERVER" \
    --certificate-authority="$SA_DIR/ca.crt" \
    --embed-certs=true >/dev/null

  kubectl config --kubeconfig="$KCFG" set-credentials service-account \
    --token="$TOKEN" >/dev/null

  kubectl config --kubeconfig="$KCFG" set-context incluster \
    --cluster=incluster \
    --user=service-account \
    --namespace="$NAMESPACE" >/dev/null

  kubectl config --kubeconfig="$KCFG" use-context incluster >/dev/null
  export KUBECONFIG="$KCFG"
fi

# if thrown flags immediately,
# assume they want to run the blockchain daemon
if [ "$(printf '%s' "$1" | cut -c 1)" = '-' ]; then
	set -- tini -s -- node openclaw.mjs gateway "$@"
fi

exec "$@"
