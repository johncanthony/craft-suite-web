#!/usr/bin/env bash
# Generate site/index.html, the landing page: index/template.html with
# index/style.css inlined, and one card per app from apps.tsv grouped by
# index/sections.tsv, each with its glyph from index/icons/<path>.svg.
# The result is one self-contained file: no JavaScript, no external
# requests (fonts are system fonts; the grain and favicon are data: URIs).
source "$(dirname "$0")/lib.sh"

BUILD_SHA="${BUILD_SHA:-dev}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%F)}"
IDX="$ROOT/index"
TMP="$CACHE/.index"; rm -rf "$TMP"; mkdir -p "$TMP"

esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

# One card. $1 = app path.
card() {
  local row; row="$(apps | awk -F'\t' -v p="$1" '$1 == p')"
  [ -n "$row" ] || die "sections.tsv names '$1', which is not in apps.tsv"
  local path repo version zipbase title blurb
  IFS=$'\t' read -r path repo version zipbase title blurb <<< "$row"
  local icon="$IDX/icons/$path.svg"
  [ -f "$icon" ] || icon="$IDX/icons/_default.svg"
  cat <<EOF
        <a class="app" href="/$path/" data-app="$path">
          <span class="top"><span class="glyph">$(cat "$icon")</span><span class="ver">v$(printf '%s' "$version" | esc)</span></span>
          <span class="name">$(printf '%s' "$title" | esc)</span>
          <span class="blurb">$(printf '%s' "$blurb" | esc)</span>
          <span class="go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg></span>
        </a>
EOF
  echo "$path" >> "$TMP/covered"
}

section() {  # id title blurb apps...
  local id="$1" title="$2" blurb="$3"; shift 3
  n=$((n+1))
  {
    printf '    <section class="section section-%s" aria-labelledby="s-%s">\n' "$id" "$id"
    printf '      <div class="section-head"><span class="n">%02d</span><h2 id="s-%s">%s</h2><p>%s</p></div>\n' \
      "$n" "$id" "$(printf '%s' "$title" | esc)" "$(printf '%s' "$blurb" | esc)"
    printf '      <div class="grid">\n'
    for a in "$@"; do card "$a"; done
    printf '      </div>\n    </section>\n'
  } >> "$TMP/sections.html"
}

n=0; : > "$TMP/sections.html"; : > "$TMP/covered"
grep -vE '^\s*(#|$)' "$IDX/sections.tsv" | while IFS=$'\t' read -r id title blurb list; do
  # shellcheck disable=SC2086
  section "$id" "$title" "$blurb" $list
done
# Anything apps.tsv has that no section claims still gets a card.
rest="$(comm -23 <(apps | cut -f1 | sort) <(sort -u "$TMP/covered") | tr '\n' ' ')"
if [ -n "${rest// /}" ]; then
  # shellcheck disable=SC2086
  section more "More" "Also on this server." $rest
fi

# Assemble: inline the CSS and the sections, then stamp the build.
awk -v css="$IDX/style.css" -v sec="$TMP/sections.html" '
  /@@CSS@@/      { while ((getline l < css) > 0) print l; next }
  /@@SECTIONS@@/ { while ((getline l < sec) > 0) print l; next }
  { print }' "$IDX/template.html" \
  | sed -e "s|@@BUILD_SHA@@|${BUILD_SHA:0:12}|g" -e "s|@@BUILD_DATE@@|${BUILD_DATE%%T*}|g" \
  > "$SITE/index.html"

rm -rf "$TMP"
log "index  $SITE/index.html ($(apps | wc -l | tr -d ' ') apps, $(wc -c < "$SITE/index.html" | tr -d ' ') bytes)"
