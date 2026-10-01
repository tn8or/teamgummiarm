# Stage 1: Build the Hugo site
FROM ghcr.io/gohugoio/hugo:v0.167.0 AS builder
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
RUN hugo --minify

# Stage 2: Serve with nginx
FROM nginx:1.31.6-alpine
COPY --from=builder /src/public /usr/share/nginx/html
COPY nginx/nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
