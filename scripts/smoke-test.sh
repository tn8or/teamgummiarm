#!/usr/bin/env bash
# Smoke-tests a Hugo build in ./public through the Worker, served locally by
# `wrangler dev`. CI runs it once per variant it builds.
#
#   scripts/smoke-test.sh production|staging
#
# Needs wrangler on PATH and a built site in ./public.
set -euo pipefail

variant=${1:?usage: smoke-test.sh production|staging}
port=${SMOKE_PORT:-8787}
base="http://127.0.0.1:$port"
log=$(mktemp)

# A Markdown file without an HTML sibling, to check the content type.
printf "# smoke \342\200\223 test\n" > public/ci-smoke.md
trap 'rm -f public/ci-smoke.md' EXIT

wrangler dev --ip 127.0.0.1 --port "$port" --show-interactive-dev-session=false >"$log" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true; rm -f public/ci-smoke.md; echo "--- wrangler dev log"; cat "$log"' EXIT
for _ in $(seq 1 60); do
  curl -fsS -o /dev/null "$base/" 2>/dev/null && break
  sleep 1
done

echo "GET / ..."
curl -fsS -o /dev/null -w '%{http_code} %{content_type}\n' "$base/"

echo "GET missing page returns 404 ..."
code=$(curl -s -o /dev/null -w '%{http_code}' "$base/ci-smoke-missing")
test "$code" = 404

echo "GET .md is served inline as UTF-8 markdown ..."
ctype=$(curl -fsS -o /dev/null -w '%{content_type}' "$base/ci-smoke.md")
echo "$ctype"
test "$ctype" = "text/markdown; charset=utf-8"

echo "Content negotiation: HTML by default, Markdown on Accept: text/markdown ..."
body=$(mktemp)
check() { # path, Accept header, expected content type
  out=$(curl -fsS -D - -o "$body" -H "Accept: $2" "$base$1")
  echo "$1 [$2] -> $(echo "$out" | grep -i '^content-type:' | tr -d '\r')"
  echo "$out" | grep -qi "^content-type: $3"
  echo "$out" | grep -qi '^vary: .*accept'
  echo "$out" | grep -qi '^cache-control: private'
}
browser='text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
for path in / /about/ /posts/; do
  check "$path" "$browser" "text/html"
  check "$path" "*/*" "text/html"
  check "$path" "text/markdown" "text/markdown; charset=utf-8"
  head -n 1 "$body" | grep -q '^# '
  check "$path" "text/markdown, text/html;q=0.9" "text/markdown"
  check "$path" "text/markdown;q=0, text/html" "text/html"
done

echo "GET /robots.txt is 200 text/plain with content signals and a sitemap ..."
out=$(curl -fsS -w '\n%{http_code} %{content_type}' "$base/robots.txt")
echo "$out"
echo "$out" | tail -n1 | grep -q '^200 text/plain'
echo "$out" | grep -q '^User-agent: \*$'
echo "$out" | grep -q '^Content-Signal: search=yes, ai-input=yes, ai-train=yes$'
echo "$out" | grep -q '^Sitemap: https://.*/sitemap\.xml$'
if [ "$variant" = staging ]; then
  echo "Staging build is not indexable ..."
  echo "$out" | grep -q '^Disallow: /$'
  curl -fsS "$base/" | grep -Eq '<meta name="?robots"? content="?noindex'
else
  echo "Production build is indexable ..."
  echo "$out" | grep -q '^Allow: /$'
  if curl -fsS "$base/" | grep -q noindex; then
    echo "Production page has noindex"; exit 1
  fi
fi
echo "Smoke test passed ($variant)."
