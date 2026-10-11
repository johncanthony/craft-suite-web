# craft-suite-web

Packages the [Craft App Suite](https://getartcraft.com/apps) web builds
(PhotoCraft, FilmCraft, LightCraft, and the rest, by [storytold](https://github.com/storytold))
into one nginx image for the memant k3s cluster. Served at `https://crafts.memant.net/`,
one app per path (`/photocraft/`, `/filmcraft/`, …), with a static index at the root.

Nothing is compiled here. Each app's official `*-web-<version>.zip` is downloaded from
its GitHub release, verified against that release's `SHA256SUMS.txt`, scanned for
outbound hostnames, gzipped, and copied into `nginxinc/nginx-unprivileged`.

## Layout

| File | Role |
|---|---|
| `apps.tsv` | The single source of truth: each app's repo, pinned version, zip name and title |
| `scan-allowlist.txt` | Hostnames allowed to appear in the apps' JS/wasm; anything else fails the build |
| `scripts/fetch.sh` | Download, verify sha256, unpack into `site/<path>/` |
| `scripts/scan.sh` | Extract hostnames from `.js` and `.wasm`, compare with the allowlist |
| `scripts/build-index.sh` | Generate the root `index.html` listing apps and versions |
| `scripts/precompress.sh` | Write `.gz` beside every compressible file for `gzip_static` |
| `nginx.conf` | Wasm MIME type, cache headers, no SPA fallback, `/healthz` |
| `Dockerfile` | Stage 1 assembles on the build host's arch; stage 2 copies into multi-arch nginx |
| `.github/workflows/build.yml` | Builds amd64+arm64 and pushes `ghcr.io/johncanthony/craft-suite-web:<sha>` |

## Updating an app

1. Change its `version` in `apps.tsv`.
2. Push to `main`. CI fetches, verifies, scans and pushes a new image tagged by commit SHA.
   If the scan reports a hostname not on the allowlist, look at what upstream added
   before allowlisting it.
3. Bump the tag in the ArgoCD repo (`apps/craft-suite/manifests/kustomization.yaml`).

## Local check (no Docker needed)

```sh
./scripts/fetch.sh && ./scripts/scan.sh && ./scripts/build-index.sh && ./scripts/precompress.sh
cd site && python3 -m http.server 8765   # then open http://localhost:8765/
```

The Python server does not send the wasm MIME type or gzip; it is enough to confirm
the files unpack and the index links resolve. The nginx config is exercised by the image.

## What the apps do and do not do

They run entirely in the visitor's browser (WebGPU or WebGL2 required; HTTPS enables
WebGPU and clipboard). Open uses the browser file picker, Save and Export download a
file. Preferences live in `localStorage`, scoped to the origin and shared across the
apps on one hostname. No server-side storage, no accounts, no telemetry: the only
network calls are to this server for the page, the wasm and optional fonts.

The one exception is `/launcher/`, the ArtCraft Launcher catalog, which calls
`api.github.com` from the browser to list releases. It is allowlisted for that app only.
