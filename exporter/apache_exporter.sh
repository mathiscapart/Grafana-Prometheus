#!/usr/bin/env bash
# Installe apache_exporter (service systemd, basic auth via web.yml).
# Apache doit exposer mod_status sur APACHE_SCRAPE_URI.
# Usage : sudo VERSION=x.y.z ./apache_exporter.sh   — cf. doc/securisation-exporters.md
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

VERSION="${VERSION:?VERSION requise, ex. VERSION=X.Y.Z (github.com/Lusitaniae/apache_exporter/releases)}"
PORT="${PORT:-9117}"
APACHE_SCRAPE_URI="${APACHE_SCRAPE_URI:-http://localhost/server-status?auto}"

require_root
install_prerequisites
create_user
write_web_config
install_binary "https://github.com/Lusitaniae/apache_exporter/releases/download/v$VERSION/apache_exporter-$VERSION.linux-$(detect_arch).tar.gz" apache_exporter
install_service apache_exporter "$EXPORTERS_USER" /usr/local/bin/apache_exporter \
    --scrape_uri="$APACHE_SCRAPE_URI" --web.listen-address=":$PORT" --web.config.file="$WEB_CONFIG"
verify_service apache_exporter "$PORT" 401
