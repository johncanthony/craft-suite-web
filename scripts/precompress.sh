#!/usr/bin/env bash
# Precompress for nginx's gzip_static, and shrink the image.
#
# The big binaries (.wasm, .js, fonts) are kept ONLY as .gz: nginx serves
# them with `gzip_static always` and decompresses on the fly (`gunzip on`)
# for the rare client that does not accept gzip. That takes the site from
# ~490 MB to ~200 MB, which matters for image pulls onto Pi SD cards.
# Everything else (html, css, json, svg, txt) keeps its original beside a .gz.
#
# Upstream .br files are removed: stock nginx has no brotli module.
source "$(dirname "$0")/lib.sh"

find "$SITE" -type f -name '*.br' -delete

n=0; d=0
while IFS= read -r -d '' f; do
  gzip -9 -k -f -n "$f"; n=$((n+1))
  case "$f" in
    *.wasm|*.js|*.mjs|*.otf|*.ttf) rm -f "$f"; d=$((d+1)) ;;
  esac
done < <(find "$SITE" -type f \( -name '*.wasm' -o -name '*.js' -o -name '*.mjs' -o -name '*.html' \
           -o -name '*.css' -o -name '*.json' -o -name '*.svg' -o -name '*.txt' \
           -o -name '*.otf' -o -name '*.ttf' \) -print0)
log "gzip   $n files; $d originals dropped (served from .gz only)"
