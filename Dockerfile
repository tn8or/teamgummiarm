# Stage 1: Build the Hugo site
FROM ghcr.io/gohugoio/hugo:v0.169.0 AS builder
WORKDIR /src
COPY . .
# .git is excluded from the build context, so the source revision has to be
# passed in. CI sets this to github.sha. Locally:
#   docker build --build-arg GIT_COMMIT=$(git rev-parse HEAD) .
ARG GIT_COMMIT=
ENV HUGO_PARAMS_commit=${GIT_COMMIT}
# The official image runs as the unprivileged "hugo" user, which can't write
# to the root-owned /src (build lock, public/). This is a throwaway builder stage.
USER root
# Empty = production (baseURL from hugo.toml, future-dated posts left out).
# PR builds set the staging URL (the theme links CSS/JS with absolute baseURL
# URLs, so it has to match the host): future-dated posts are included so they
# can be previewed, and the site is noindex (params.staging).
ARG STAGING_URL=
# Changes on every CI run, so the Hugo step is never served from the layer
# cache: buildFuture=false decides on the build day, which the cache key
# would not otherwise see.
ARG BUILD_TIME=
RUN if [ -n "$STAGING_URL" ]; then \
      HUGO_PARAMS_staging=true hugo --minify --baseURL "$STAGING_URL" --buildFuture; \
    else \
      hugo --minify; \
    fi

# Stage 2: Serve with nginx
FROM nginx:1.31.8-alpine
COPY --from=builder /src/public /usr/share/nginx/html
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/
EXPOSE 80
