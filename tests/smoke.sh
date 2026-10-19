#!/usr/bin/env bash
# Test de fumée de la stack : build, démarrage, configs rendues valides, rules chargées,
# et scrape d'un node_exporter protégé par web.yml (basic auth).
# Usage : ENV_FILE=chemin/vers/.env NODE_EXPORTER_VERSION=vX.Y.Z tests/smoke.sh
# ⚠️ Démonte la stack (volumes compris) à la fin : ne pas lancer sur un serveur en production.
set -euo pipefail

cd "$(dirname "$0")/.."
ENV_FILE="${ENV_FILE:-.env}"
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:?NODE_EXPORTER_VERSION requis}"
NODE_TARGETS=prometheus/targets/node.json
SMOKE_NODE=smoke-node-exporter

compose() { docker compose --env-file "$ENV_FILE" "$@"; }
fail() { echo "ÉCHEC : $*" >&2; exit 1; }

if [ -e "$NODE_TARGETS" ]; then
  fail "$NODE_TARGETS existe déjà, le test ne l'écrase pas"
fi

cleanup() {
  docker rm -f "$SMOKE_NODE" >/dev/null 2>&1 || true
  rm -f "$NODE_TARGETS"
  compose down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

echo "==> Build et démarrage"
# Cible écrite avant le démarrage : sous Docker Desktop (Windows/macOS) les
# modifications d'un bind mount ne sont pas toujours notifiées à file_sd.
echo "[{\"targets\": [\"$SMOKE_NODE:9100\"]}]" > "$NODE_TARGETS"
compose up -d --build --wait

echo "==> Configurations rendues"
compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
compose exec -T alertmanager amtool check-config /etc/alertmanager/alertmanager.yml

echo "==> node_exporter protégé par web.yml"
hash=$(docker run --rm httpd:alpine htpasswd -nbBC 10 "" "$EXPORTER_BASIC_AUTH_PASSWORD" | tr -d ':\n')
network=$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$(compose ps -q prometheus)")
docker run -d --name "$SMOKE_NODE" --network "$network" \
  -e WEB_YML="basic_auth_users: {'$EXPORTER_BASIC_AUTH_USERNAME': '$hash'}" \
  --entrypoint /bin/sh "prom/node-exporter:$NODE_EXPORTER_VERSION" \
  -c 'printf "%s\n" "$WEB_YML" > /tmp/web.yml && exec /bin/node_exporter --web.config.file=/tmp/web.yml' >/dev/null

if compose exec -T prometheus wget -q -O /dev/null "http://$SMOKE_NODE:9100/metrics" 2>/dev/null; then
  fail "l'exporter répond sans authentification"
fi

echo "==> Prometheus scrape l'exporter avec basic auth"
for _ in $(seq 30); do
  health=$(compose exec -T prometheus wget -q -O - http://localhost:9090/api/v1/targets \
    | grep -o "\"scrapeUrl\":\"http://$SMOKE_NODE:9100/metrics\"[^}]*\"health\":\"[a-z]*\"" \
    | grep -o '"health":"[a-z]*"' || true)
  [ "$health" = '"health":"up"' ] && break
  sleep 2
done
[ "$health" = '"health":"up"' ] || fail "cible node non UP ($health)"

echo "==> Rules chargées"
compose exec -T prometheus wget -q -O - http://localhost:9090/api/v1/rules | grep -q '"name":"node.rules"' \
  || fail "rules non chargées"

echo "OK"
