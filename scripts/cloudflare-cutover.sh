#!/usr/bin/env bash
# Moves teamgummiarm.dk from the home k3s cluster (Cloudflare Tunnel) to the
# Cloudflare Worker that CI deploys, and back again if needed.
#
#   CF_API_TOKEN=... scripts/cloudflare-cutover.sh <command> <staging|production>
#
# Commands, in the order you'd run them:
#   status     Show the Worker, Workers routes and DNS records for the hosts.
#   route      Attach Workers routes (host/*) to the Worker. Takes effect at
#              once: the proxied DNS record stays as it is, but the Worker
#              answers before the request reaches the tunnel. Fully reversible.
#   dns        Replace the tunnel CNAME with a proxied AAAA 100:: placeholder
#              (the usual "Worker-only" record), so the host no longer depends
#              on the tunnel. Run it once `route` has been verified.
#   rollback   Restore the tunnel CNAME (if `dns` ran) and remove the routes.
#              The site is then served by k3s again, with the last image it had.
#
# The token needs: Zone > Workers Routes: Edit and Zone > DNS: Edit on the zone,
# Account > Workers Scripts: Read on the account. Requires curl and jq.
set -euo pipefail

ZONE=teamgummiarm.dk
ACCOUNT_ID=41d50f6affa3ee547a0a40ce3ced46a9
TUNNEL_TARGET=14dbf450-38b7-43b2-9afe-73fde608493e.cfargotunnel.com

hosts() {
  case $1 in
    production) echo "teamgummiarm.dk www.teamgummiarm.dk" ;;
    staging) echo "staging.teamgummiarm.dk" ;;
    *) echo "unknown target: $1 (staging|production)" >&2; exit 2 ;;
  esac
}
worker() {
  case $1 in
    production) echo teamgummiarm ;;
    staging) echo teamgummiarm-staging ;;
  esac
}

cmd=${1:-}; target=${2:-}
if [ -z "$cmd" ] || [ -z "$target" ]; then
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2
fi
: "${CF_API_TOKEN:?set CF_API_TOKEN}"
HOSTS=$(hosts "$target"); WORKER=$(worker "$target")

api() { # method path [json]
  local out
  out=$(curl -sS -X "$1" "https://api.cloudflare.com/client/v4$2" \
    -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
    ${3:+--data "$3"})
  if [ "$(jq -r .success <<<"$out")" != true ]; then
    echo "API $1 $2 failed: $(jq -c .errors <<<"$out")" >&2; exit 1
  fi
  echo "$out"
}

ZONE_ID=$(api GET "/zones?name=$ZONE" | jq -r '.result[0].id')
[ -n "$ZONE_ID" ] && [ "$ZONE_ID" != null ] || { echo "zone $ZONE not found" >&2; exit 1; }

routes() { api GET "/zones/$ZONE_ID/workers/routes" | jq -c '.result[]'; }
record() { api GET "/zones/$ZONE_ID/dns_records?name.exact=$1" | jq -c '[.result[] | select(.type == "CNAME" or .type == "A" or .type == "AAAA")]'; }

require_worker() {
  if ! api GET "/accounts/$ACCOUNT_ID/workers/scripts" | jq -e --arg w "$WORKER" '.result[] | select(.id == $w)' >/dev/null; then
    echo "Worker $WORKER does not exist yet. Merge the PR and let CI deploy it first." >&2; exit 1
  fi
}

probe() {
  for host in $HOSTS; do
    for path in / /robots.txt; do
      printf '  https://%s%s -> ' "$host" "$path"
      curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' "https://$host$path" || true
    done
    printf '  https://%s/ [Accept: text/markdown] -> ' "$host"
    curl -sS -o /dev/null -H 'Accept: text/markdown' -w '%{http_code} %{content_type}\n' "https://$host/" || true
  done
}

case $cmd in
  status)
    if api GET "/accounts/$ACCOUNT_ID/workers/scripts" | jq -e --arg w "$WORKER" '.result[] | select(.id == $w)' >/dev/null; then
      echo "Worker $WORKER: deployed"
    else
      echo "Worker $WORKER: not deployed yet"
    fi
    for host in $HOSTS; do
      echo "$host"
      echo "  routes: $(routes | jq -r --arg p "$host/*" 'select(.pattern == $p) | "\(.pattern) -> \(.script)"' | paste -sd, -)"
      echo "  dns:    $(record "$host" | jq -r '.[] | "\(.type) \(.content) proxied=\(.proxied)"' | paste -sd, -)"
    done
    ;;

  route)
    require_worker
    for host in $HOSTS; do
      pattern="$host/*"
      existing=$(routes | jq -r --arg p "$pattern" 'select(.pattern == $p) | .id')
      if [ -n "$existing" ]; then
        api PUT "/zones/$ZONE_ID/workers/routes/$existing" "$(jq -nc --arg p "$pattern" --arg s "$WORKER" '{pattern: $p, script: $s}')" >/dev/null
        echo "updated route $pattern -> $WORKER"
      else
        api POST "/zones/$ZONE_ID/workers/routes" "$(jq -nc --arg p "$pattern" --arg s "$WORKER" '{pattern: $p, script: $s}')" >/dev/null
        echo "added route $pattern -> $WORKER"
      fi
    done
    echo "Checking the hosts (expect 200, text/html and text/markdown):"
    probe
    ;;

  dns)
    for host in $HOSTS; do
      routes | jq -e --arg p "$host/*" --arg s "$WORKER" 'select(.pattern == $p and .script == $s)' >/dev/null \
        || { echo "no route $host/* -> $WORKER; run 'route $target' first" >&2; exit 1; }
    done
    for host in $HOSTS; do
      rec=$(record "$host")
      if jq -e 'length == 1 and .[0].type == "AAAA" and .[0].content == "100::"' <<<"$rec" >/dev/null; then
        echo "$host: already AAAA 100::"; continue
      fi
      # Delete and create in one atomic batch, so the name never disappears.
      batch=$(jq -nc --argjson rec "$rec" --arg name "$host" '{
        deletes: [$rec[] | {id}],
        posts: [{type: "AAAA", name: $name, content: "100::", proxied: true, ttl: 1,
                 comment: "Served by the Workers route; see scripts/cloudflare-cutover.sh"}]
      }')
      api POST "/zones/$ZONE_ID/dns_records/batch" "$batch" >/dev/null
      echo "$host: $(jq -r '[.[] | "\(.type) \(.content)"] | join(",")' <<<"$rec") -> AAAA 100:: (proxied)"
    done
    probe
    ;;

  rollback)
    for host in $HOSTS; do
      rec=$(record "$host")
      if jq -e 'any(.[]; .type == "CNAME" and .content == "'"$TUNNEL_TARGET"'")' <<<"$rec" >/dev/null; then
        echo "$host: DNS already points at the tunnel"
      else
        batch=$(jq -nc --argjson rec "$rec" --arg name "$host" --arg t "$TUNNEL_TARGET" '{
          deletes: [$rec[] | {id}],
          posts: [{type: "CNAME", name: $name, content: $t, proxied: true, ttl: 1}]
        }')
        api POST "/zones/$ZONE_ID/dns_records/batch" "$batch" >/dev/null
        echo "$host: DNS -> CNAME $TUNNEL_TARGET (proxied)"
      fi
      for id in $(routes | jq -r --arg p "$host/*" 'select(.pattern == $p) | .id'); do
        api DELETE "/zones/$ZONE_ID/workers/routes/$id" >/dev/null
        echo "$host: removed route $host/*"
      done
    done
    probe
    ;;

  *) echo "unknown command: $cmd" >&2; exit 2 ;;
esac
