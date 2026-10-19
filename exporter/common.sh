#!/usr/bin/env bash
# Fonctions communes aux scripts d'installation des exporters (sourcé, pas exécuté).
# Chaque exporter : binaire dans /usr/local/bin, service systemd, utilisateur système
# « prometheus », basic auth via /etc/prometheus-exporters/<exporter>.web.yml
# (cf. doc/securisation-exporters.md).

readonly EXPORTERS_USER=prometheus
readonly EXPORTERS_CONFIG_DIR=/etc/prometheus-exporters

log() { echo "[INFO] $*"; }
die() { echo "[ERREUR] $*" >&2; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "à lancer en root (sudo)"
}

# amd64 ou arm64, tel que nommé dans les archives des releases
detect_arch() {
    case "$(uname -m)" in
        x86_64) echo amd64 ;;
        aarch64 | arm64) echo arm64 ;;
        *) die "architecture non supportée : $(uname -m)" ;;
    esac
}

install_prerequisites() {
    if command -v curl >/dev/null && command -v tar >/dev/null && command -v htpasswd >/dev/null; then
        return
    fi
    log "Installation des prérequis (curl, tar, htpasswd)"
    if command -v apt-get >/dev/null; then
        apt-get update -qq
        apt-get install -y -qq curl ca-certificates tar apache2-utils
    elif command -v dnf >/dev/null; then
        dnf install -y -q curl tar httpd-tools
    else
        die "gestionnaire de paquets non supporté : installer curl, tar et htpasswd"
    fi
}

create_user() {
    if ! id -u "$EXPORTERS_USER" >/dev/null 2>&1; then
        log "Création de l'utilisateur système $EXPORTERS_USER"
        useradd --system --user-group --no-create-home --shell /usr/sbin/nologin "$EXPORTERS_USER"
    fi
    install -d -m 0750 -o root -g "$EXPORTERS_USER" "$EXPORTERS_CONFIG_DIR"
}

# write_web_config <fichier web.yml> <PRÉFIXE>
# Identifiants : <PRÉFIXE>_BASIC_AUTH_USERNAME / <PRÉFIXE>_BASIC_AUTH_PASSWORD (mêmes noms
# que dans le .env de la stack), demandés s'ils sont absents. Un fichier existant est
# conservé, sauf WEB_CONFIG_RESET=1 (ex. après un changement de mot de passe dans le .env).
write_web_config() {
    local file=$1 user_var="$2_BASIC_AUTH_USERNAME" password_var="$2_BASIC_AUTH_PASSWORD" user password hash
    if [ -f "$file" ] && [ "${WEB_CONFIG_RESET:-0}" != 1 ]; then
        log "$file existant conservé"
        return
    fi
    user="${!user_var:-}"
    password="${!password_var:-}"
    [ -n "$user" ] || read -rp "Utilisateur basic auth ($user_var) : " user || true
    [ -n "$password" ] || { read -rsp "Mot de passe basic auth ($password_var) : " password || true; echo; }
    [ -n "$user" ] && [ -n "$password" ] || die "identifiants basic auth requis ($user_var, $password_var)"
    [[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] || die "utilisateur basic auth invalide (lettres, chiffres, . _ -)"

    hash=$(htpasswd -nbBC 10 "" "$password" | tr -d ':\n')
    log "Écriture de $file"
    cat >"$file" <<EOF
# Généré par exporter/common.sh : basic auth de l'exporter (exporter-toolkit)
basic_auth_users:
  $user: '$hash'
EOF
    chown root:"$EXPORTERS_USER" "$file"
    chmod 0640 "$file"
}

# install_binary <url de l'archive> <nom du binaire>
install_binary() {
    local url=$1 binary=$2 tmp file
    tmp=$(mktemp -d)
    log "Téléchargement de $url"
    curl -fsSL "$url" | tar -xz -C "$tmp"
    file=$(find "$tmp" -type f -name "$binary" | head -n 1)
    [ -n "$file" ] || die "$binary introuvable dans l'archive"
    install -m 0755 "$file" "/usr/local/bin/$binary"
    rm -rf "$tmp"
}

# install_service <nom> <utilisateur> <commande et arguments...>
install_service() {
    local name=$1 user=$2
    shift 2
    log "Installation du service $name"
    cat >"/etc/systemd/system/$name.service" <<EOF
[Unit]
Description=Prometheus $name
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$user
Group=$user
ExecStart=$*
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --quiet "$name"
    systemctl restart "$name"
}

# verify_service <nom> <port> <code HTTP attendu sans identifiants : 401 si basic auth>
verify_service() {
    local name=$1 port=$2 expected=$3 code=000
    for _ in $(seq 10); do
        code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/metrics" || true)
        [ "$code" = "$expected" ] && break
        sleep 1
    done
    systemctl is-active --quiet "$name" || die "$name ne tourne pas : journalctl -u $name"
    [ "$code" = "$expected" ] || die "$name répond $code au lieu de $expected sur le port $port"
    log "$name installé et actif sur le port $port"
}
