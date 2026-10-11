#!/usr/bin/env bash
# Download each app's web release zip, verify it against the release's
# SHA256SUMS.txt, and unpack it into site/<path>/.
#
# Upstream built and signed these; we only package them. Nothing is
# compiled here.
source "$(dirname "$0")/lib.sh"

mkdir -p "$CACHE" "$SITE"

apps | while IFS=$'\t' read -r path repo version zipbase title blurb; do
  zip="${zipbase}-${version}.zip"
  base="https://github.com/${repo}/releases/download/v${version}"
  dir="$CACHE/${path}-${version}"
  mkdir -p "$dir"

  if [ ! -f "$dir/$zip" ] || [ ! -f "$dir/SHA256SUMS.txt" ]; then
    log "fetch  $repo v$version  $zip"
    curl -fsSL --retry 3 -o "$dir/SHA256SUMS.txt" "$base/SHA256SUMS.txt"
    curl -fsSL --retry 3 -o "$dir/$zip" "$base/$zip"
  else
    log "cached $repo v$version  $zip"
  fi

  expected="$(awk -v f="$zip" '$2 == f || $2 == "*"f {print $1}' "$dir/SHA256SUMS.txt")"
  [ -n "$expected" ] || die "$zip not listed in $repo v$version SHA256SUMS.txt"
  actual="$(sha256 "$dir/$zip")"
  [ "$actual" = "$expected" ] || die "checksum mismatch for $zip: expected $expected got $actual"
  log "verify $zip  sha256 ok"

  # Unpack. The zip holds one top-level directory (<zipbase>-<version>/);
  # we strip it so the site lives directly at site/<path>/.
  tmp="$(mktemp -d)"
  unzip -q "$dir/$zip" -d "$tmp"
  top="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [ -n "$top" ] && [ -f "$top/index.html" ] || die "$zip: expected a single top-level dir containing index.html"
  rm -rf "${SITE:?}/$path"
  mv "$top" "$SITE/$path"
  rm -rf "$tmp"

  # Host-specific sample config and hosting docs; not served. Licences stay.
  rm -f "$SITE/$path/_headers" "$SITE/$path/.htaccess" "$SITE/$path/HOSTING.md" "$SITE/$path/README.md"
  # lightcraft 0.6.0 shipped a Cargo target directory inside its web zip
  # (build/, deps/, .fingerprint/ ... ~115 MB of .d and .rlib files). Strip
  # Cargo leftovers wherever they appear; nothing in a site needs them.
  for junk in build deps examples incremental .fingerprint; do
    if [ -d "$SITE/$path/$junk" ]; then
      log "strip  $path/$junk ($(du -sh "$SITE/$path/$junk" | cut -f1)) - Cargo leftovers in the upstream zip"
      rm -rf "${SITE:?}/$path/$junk"
    fi
  done
  printf '%s\n' "$version" > "$SITE/$path/.version"
done

log "fetched $(apps | wc -l | tr -d ' ') apps into $SITE"
