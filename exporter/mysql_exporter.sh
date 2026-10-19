#!/usr/bin/env bash
# Installe mysqld_exporter (service systemd, basic auth via web.yml) sur le serveur MySQL/MariaDB,
# et crée l'utilisateur MySQL de l'exporter (accès root MySQL via socket, ou MYSQL_ROOT_PASSWORD).
# Usage : sudo VERSION=x.y.z ./mysql_exporter.sh   — cf. doc/securisation-exporters.md
#   MYSQL_EXPORTER_PASSWORD : mot de passe de l'utilisateur MySQL de l'exporter (demandé si absent)
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

VERSION="${VERSION:?VERSION requise, ex. VERSION=X.Y.Z (github.com/prometheus/mysqld_exporter/releases)}"
PORT="${PORT:-9104}"
MYSQL_EXPORTER_USER="${MYSQL_EXPORTER_USER:-exporter}"
MYSQL_EXPORTER_PASSWORD="${MYSQL_EXPORTER_PASSWORD:-}"
MY_CNF="$EXPORTERS_CONFIG_DIR/mysqld_exporter.cnf"
WEB_CONFIG="$EXPORTERS_CONFIG_DIR/mysqld_exporter.web.yml"

require_root
command -v mysql >/dev/null || die "client mysql introuvable : lancer ce script sur le serveur MySQL/MariaDB"
[ -n "$MYSQL_EXPORTER_PASSWORD" ] || { read -rsp "Mot de passe MySQL de l'exporter : " MYSQL_EXPORTER_PASSWORD || true; echo; }
[ -n "$MYSQL_EXPORTER_PASSWORD" ] || die "MYSQL_EXPORTER_PASSWORD requis"
[[ "$MYSQL_EXPORTER_PASSWORD" != *[\'\\]* ]] || die "MYSQL_EXPORTER_PASSWORD ne doit contenir ni apostrophe ni antislash"

install_prerequisites
create_user
write_web_config "$WEB_CONFIG" MYSQL

log "Création de l'utilisateur MySQL $MYSQL_EXPORTER_USER@localhost"
MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-}" mysql -u root <<SQL
CREATE USER IF NOT EXISTS '$MYSQL_EXPORTER_USER'@'localhost' IDENTIFIED BY '$MYSQL_EXPORTER_PASSWORD' WITH MAX_USER_CONNECTIONS 3;
ALTER USER '$MYSQL_EXPORTER_USER'@'localhost' IDENTIFIED BY '$MYSQL_EXPORTER_PASSWORD';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '$MYSQL_EXPORTER_USER'@'localhost';
SQL

log "Écriture de $MY_CNF"
cat >"$MY_CNF" <<CNF
[client]
user=$MYSQL_EXPORTER_USER
password=$MYSQL_EXPORTER_PASSWORD
host=localhost
port=3306
CNF
chown root:"$EXPORTERS_USER" "$MY_CNF"
chmod 0640 "$MY_CNF"

install_binary "https://github.com/prometheus/mysqld_exporter/releases/download/v$VERSION/mysqld_exporter-$VERSION.linux-$(detect_arch).tar.gz" mysqld_exporter
install_service mysqld-exporter "$EXPORTERS_USER" /usr/local/bin/mysqld_exporter \
    --config.my-cnf="$MY_CNF" \
    --collect.global_status \
    --collect.info_schema.innodb_metrics \
    --collect.auto_increment.columns \
    --collect.info_schema.processlist \
    --collect.binlog_size \
    --collect.info_schema.tablestats \
    --collect.global_variables \
    --collect.info_schema.query_response_time \
    --collect.info_schema.userstats \
    --collect.info_schema.tables \
    --collect.perf_schema.tablelocks \
    --collect.perf_schema.file_events \
    --collect.perf_schema.eventswaits \
    --collect.perf_schema.indexiowaits \
    --collect.perf_schema.tableiowaits \
    --collect.slave_status \
    --web.listen-address=":$PORT" --web.config.file="$WEB_CONFIG"
verify_service mysqld-exporter "$PORT" 401
