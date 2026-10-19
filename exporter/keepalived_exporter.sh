#!/usr/bin/env bash
# Installe keepalived-exporter (mehdy) en service systemd.
# ⚠️ Cet exporter ne gère pas --web.config.file : pas de basic auth possible,
# ses métriques restent accessibles sans authentification (cf. doc/securisation-exporters.md).
# Il tourne en root : il signale keepalived (via son PID) pour obtenir ses statistiques.
# Usage : sudo VERSION=x.y.z ./keepalived_exporter.sh
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

VERSION="${VERSION:?VERSION requise, ex. VERSION=X.Y.Z (github.com/mehdy/keepalived-exporter/releases)}"
PORT="${PORT:-9165}"
KEEPALIVED_PID_PATH="${KEEPALIVED_PID_PATH:-/var/run/keepalived.pid}"

require_root
install_prerequisites
install_binary "https://github.com/mehdy/keepalived-exporter/releases/download/v$VERSION/keepalived-exporter_${VERSION}_linux_$(detect_arch).tar.gz" keepalived-exporter
install_service keepalived_exporter root /usr/local/bin/keepalived-exporter \
    --ka.pid-path="$KEEPALIVED_PID_PATH" --web.listen-address=":$PORT"
verify_service keepalived_exporter "$PORT" 200
