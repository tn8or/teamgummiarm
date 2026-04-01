FROM hugomods/hugo:latest AS builder

WORKDIR /src
COPY . .

RUN hugo --minify

FROM nginx:alpine

COPY --from=builder --chown=nginx:nginx /src/public /usr/share/nginx/html

EXPOSE 80
