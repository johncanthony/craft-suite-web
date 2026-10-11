# craft-suite-web: the Craft App Suite web builds behind nginx.
#
# Stage 1 runs on the build host's own architecture (no emulation): it only
# downloads, verifies, scans and gzips files. Stage 2 is a COPY into a
# multi-arch nginx image, so the result runs on the Pi workers (arm64) and
# on amd64 alike.

FROM --platform=$BUILDPLATFORM alpine:3.21 AS assemble
RUN apk add --no-cache bash curl ca-certificates unzip gzip binutils coreutils grep
WORKDIR /src
COPY apps.tsv scan-allowlist.txt ./
COPY scripts/ scripts/
ARG BUILD_SHA=dev
ARG BUILD_DATE
RUN ./scripts/fetch.sh \
 && ./scripts/scan.sh \
 && BUILD_SHA="$BUILD_SHA" BUILD_DATE="${BUILD_DATE:-}" ./scripts/build-index.sh \
 && ./scripts/precompress.sh \
 && rm -rf .cache

# Pinned; bump deliberately. Multi-arch (amd64 + arm64).
FROM nginxinc/nginx-unprivileged:1.30.5-alpine
LABEL org.opencontainers.image.title="craft-suite-web" \
      org.opencontainers.image.description="Craft App Suite (storytold) web builds served by nginx" \
      org.opencontainers.image.source="https://github.com/johncanthony/craft-suite-web"
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=assemble /src/site/ /usr/share/nginx/html/
# Fail the build on a bad config rather than crash-looping on the cluster.
RUN nginx -t
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null || exit 1
