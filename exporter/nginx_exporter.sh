#!/usr/bin/env bash
# Installe nginx-prometheus-exporter (service systemd, basic auth via web.yml).
# Nginx doit exposer stub_status sur NGINX_SCRAPE_URI.
# Usage : sudo VERSION=x.y.z ./nginx_exporter.sh   — cf. doc/securisation-exporters.md
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

VERSION="${VERSION:?VERSION requise, ex. VERSION=X.Y.Z (github.com/nginx/nginx-prometheus-exporter/releases)}"
PORT="${PORT:-9113}"
NGINX_SCRAPE_URI="${NGINX_SCRAPE_URI:-http://127.0.0.1:8080/nginx_status}"

require_root
install_prerequisites
create_user
write_web_config
install_binary "https://github.com/nginx/nginx-prometheus-exporter/releases/download/v$VERSION/nginx-prometheus-exporter_${VERSION}_linux_$(detect_arch).tar.gz" nginx-prometheus-exporter
install_service nginx_exporter "$EXPORTERS_USER" /usr/local/bin/nginx-prometheus-exporter \
    --nginx.scrape-uri="$NGINX_SCRAPE_URI" --web.listen-address=":$PORT" --web.config.file="$WEB_CONFIG"
verify_service nginx_exporter "$PORT" 401
