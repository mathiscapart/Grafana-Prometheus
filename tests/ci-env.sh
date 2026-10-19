#!/usr/bin/env bash
# Écrit sur la sortie standard un .env de test à partir des versions de l'environnement
# (bloc env: du workflow CI) et vérifie qu'il couvre toutes les variables de .env.example.
set -euo pipefail

cd "$(dirname "$0")/.."

env_file=$(cat <<EOT
PROMETHEUS_VERSION=${PROMETHEUS_VERSION:?}
ALERTMANAGER_VERSION=${ALERTMANAGER_VERSION:?}
BLACKBOX_VERSION=${BLACKBOX_VERSION:?}
GRAFANA_VERSION=${GRAFANA_VERSION:?}
GO_VERSION=${GO_VERSION:?}
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=ci-grafana
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/0/ci
EXPORTER_BASIC_AUTH_USERNAME=prometheus
EXPORTER_BASIC_AUTH_PASSWORD=ci-p@ss#word
EOT
)

missing=$(comm -23 <(grep -oE '^[A-Z_]+' .env.example | sort) <(grep -oE '^[A-Z_]+' <<<"$env_file" | sort))
if [ -n "$missing" ]; then
  echo "Variables de .env.example absentes du .env de CI : $missing" >&2
  exit 1
fi

echo "$env_file"
