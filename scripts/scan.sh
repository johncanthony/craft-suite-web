#!/usr/bin/env bash
# Scan every unpacked app for hostnames embedded in its JavaScript and
# WebAssembly, and fail the build if any host is not on the allowlist.
#
# A hostname in the binary is not proof of a network call (most are XML
# namespaces, bug-tracker links in error messages, and About-dialog links),
# but a NEW host is exactly what should stop an automated rebuild until a
# human has looked. Known telemetry/backend hosts fail unconditionally.
#
# Per-app exceptions live in scan-allowlist.txt under "[path]" headers.
source "$(dirname "$0")/lib.sh"

ALLOW="$ROOT/scan-allowlist.txt"
TLDS='com|org|net|io|co|jp|us|rs|app|gg|dev|ai|uk|de|edu|gov|info|me|tv|xyz|cloud|fm|to|ly|sh|cc|pl|ru|cn|fr|it|nl|ch|at|ca|au|br|in|eu|se|no|fi|es|be'
DENY_RE='posthog|sentry\.io|datadoghq|mixpanel|segment\.(io|com)|storyteller\.ai|fakeyou\.com|google-analytics|googletagmanager|plausible\.io|amplitude\.com'

global_allow() { awk '/^\[/{sec=$0} /^\s*(#|$)/{next} sec==""{print}' "$ALLOW"; }
app_allow()    { awk -v s="[$1]" '/^\[/{sec=$0; next} /^\s*(#|$)/{next} sec==s{print}' "$ALLOW"; }

fail=0
apps | while IFS=$'\t' read -r path repo version zipbase title blurb; do
  dir="$SITE/$path"
  # Rust packs string literals back to back in the wasm, so a naive URL
  # regex yields junk like "getartcraft.comhttps". Require a lowercase host
  # ending in a known TLD at a word boundary; concatenated junk then simply
  # fails to match, and the same host usually appears cleanly elsewhere.
  hosts="$( { cat "$dir"/*.js; strings -n 8 "$dir"/*.wasm; } \
            | grep -oE "https?://[a-z0-9.-]+\\.($TLDS)\\b" \
            | sed -E 's#^https?://##' | sort -u )"
  allowed="$( { global_allow; app_allow "$path"; } | sort -u )"

  bad="$(comm -23 <(printf '%s\n' "$hosts") <(printf '%s\n' "$allowed") || true)"
  denied="$(printf '%s\n' "$hosts" | grep -E "$DENY_RE" || true)"
  # An app may explicitly allow a denied host (the launcher needs api.github.com,
  # which is not on the deny list, but keep the mechanism general).
  denied="$(comm -23 <(printf '%s\n' "$denied" | sort -u) <(app_allow "$path" | sort -u) || true)"

  if [ -n "$bad" ] || [ -n "$denied" ]; then
    log "FAIL   $path v$version"
    [ -n "$denied" ] && printf '         denied: %s\n' $denied >&2
    [ -n "$bad" ]    && printf '         unknown: %s\n' $bad >&2
    echo fail >> "$CACHE/.scan-fail"
  else
    log "ok     $path v$version  ($(printf '%s\n' "$hosts" | grep -c . ) hosts, all allowlisted)"
  fi
done

if [ -f "$CACHE/.scan-fail" ]; then
  rm -f "$CACHE/.scan-fail"
  die "scan found hosts not on the allowlist; review and add to scan-allowlist.txt if benign"
fi
log "scan   clean"
