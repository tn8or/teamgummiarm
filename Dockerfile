FROM hugomods/hugo:latest AS builder

WORKDIR /src
COPY . .

RUN hugo --minify

FROM nginx:alpine

COPY --from=builder --chown=nginx:nginx /src/public /usr/share/nginx/html
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
