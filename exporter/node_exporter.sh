#!/usr/bin/env bash
# Installe node_exporter (service systemd, basic auth via web.yml).
# Usage : sudo VERSION=x.y.z ./node_exporter.sh   — cf. doc/securisation-exporters.md
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

VERSION="${VERSION:?VERSION requise, ex. VERSION=X.Y.Z (github.com/prometheus/node_exporter/releases)}"
PORT="${PORT:-9100}"
WEB_CONFIG="$EXPORTERS_CONFIG_DIR/node_exporter.web.yml"

require_root
install_prerequisites
create_user
write_web_config "$WEB_CONFIG" NODE
install_binary "https://github.com/prometheus/node_exporter/releases/download/v$VERSION/node_exporter-$VERSION.linux-$(detect_arch).tar.gz" node_exporter
install_service node_exporter "$EXPORTERS_USER" /usr/local/bin/node_exporter \
    --web.listen-address=":$PORT" --web.config.file="$WEB_CONFIG"
verify_service node_exporter "$PORT" 401
