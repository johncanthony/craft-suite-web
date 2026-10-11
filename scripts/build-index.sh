#!/usr/bin/env bash
# Generate site/index.html: a static landing page listing every app with
# its pinned version. No JavaScript, no external requests.
source "$(dirname "$0")/lib.sh"

BUILD_SHA="${BUILD_SHA:-dev}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%F)}"

rows=""
apps | while IFS=$'\t' read -r path repo version zipbase title blurb; do
  printf '      <li><a href="/%s/"><strong>%s</strong> <span class="v">v%s</span></a><span class="b">%s</span></li>\n' \
    "$path" "$title" "$version" "$blurb"
done > "$CACHE/.rows"

cat > "$SITE/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Craft Suite</title>
  <style>
    :root { color-scheme: dark; --bg:#1e1e1e; --fg:#e6e6e6; --mut:#9a9a9a; --card:#2a2a2a; --acc:#8ab4f8; }
    html,body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.5 system-ui,sans-serif; }
    main { max-width: 760px; margin: 0 auto; padding: 40px 16px 64px; }
    h1 { font-size: 22px; margin: 0 0 4px; }
    p.sub { color: var(--mut); margin: 0 0 28px; }
    ul { list-style: none; padding: 0; margin: 0; display: grid; gap: 10px; }
    li { background: var(--card); border-radius: 8px; padding: 12px 16px; display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 12px; }
    li a { color: var(--fg); text-decoration: none; }
    li a:hover strong { color: var(--acc); }
    .v { color: var(--mut); font-size: 13px; margin-left: 6px; }
    .b { color: var(--mut); flex-basis: 100%; font-size: 14px; }
    footer { color: var(--mut); font-size: 12px; margin-top: 32px; }
  </style>
</head>
<body>
  <main>
    <h1>Craft Suite</h1>
    <p class="sub">Open-source creative apps from <a href="https://getartcraft.com/apps" style="color:var(--acc)">ArtCraft</a>, running entirely in your browser. Work is saved by downloading a file; there is no server-side storage.</p>
    <ul>
$(cat "$CACHE/.rows")
    </ul>
    <footer>craft-suite-web build ${BUILD_SHA} · ${BUILD_DATE} · WebGPU or WebGL2 required</footer>
  </main>
</body>
</html>
HTML
rm -f "$CACHE/.rows"
log "index  $SITE/index.html"
