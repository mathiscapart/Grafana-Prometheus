# Installation et sécurisation des exporters

Les serveurs n'ont pas de pare-feu : les exporters sont joignables par tout le réseau. Ils
sont donc protégés par **basic auth**, via le fichier `web.yml` de
[exporter-toolkit](https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md)
(`--web.config.file`). Prometheus envoie les identifiants du `.env`
(`EXPORTER_BASIC_AUTH_USERNAME` / `EXPORTER_BASIC_AUTH_PASSWORD`, blocs `basic_auth` de
`prometheus/prometheus.yml.tmpl`).

## Scripts d'installation

Un script par exporter dans `exporter/`, tous sur le même modèle (`exporter/common.sh`) :

1. installe les prérequis s'il en manque (`curl`, `tar`, `htpasswd`) ;
2. crée l'utilisateur système `prometheus` ;
3. génère `/etc/prometheus-exporters/web.yml` (hash bcrypt, `0640 root:prometheus`) ;
4. télécharge la version demandée (amd64 ou arm64 détecté) dans `/usr/local/bin` ;
5. installe et démarre le service systemd ;
6. vérifie que le service tourne et refuse un accès sans identifiants (`401`).

Copier le dossier `exporter/` sur le serveur, puis :

```bash
sudo EXPORTER_BASIC_AUTH_USERNAME=prometheus \
     EXPORTER_BASIC_AUTH_PASSWORD='<mot de passe du .env>' \
     VERSION=X.Y.Z ./node_exporter.sh
```

Les identifiants sont **les mêmes que dans le `.env` de la stack**. S'ils ne sont pas
passés en variables, le script les demande. Le `web.yml` est partagé par tous les exporters
d'un même serveur : les installations suivantes le réutilisent (`WEB_CONFIG_RESET=1` pour le
régénérer, par exemple après un changement de mot de passe dans le `.env`).

Relancer un script met à jour l'exporter (nouvelle `VERSION`) sans autre effet.

| Script | Service systemd | Port | Variables propres (défaut) |
|---|---|---|---|
| `node_exporter.sh` | `node_exporter` | 9100 | — |
| `nginx_exporter.sh` | `nginx_exporter` | 9113 | `NGINX_SCRAPE_URI` (`http://127.0.0.1:8080/nginx_status`, stub_status nginx) |
| `apache_exporter.sh` | `apache_exporter` | 9117 | `APACHE_SCRAPE_URI` (`http://localhost/server-status?auto`, mod_status) |
| `mysql_exporter.sh` | `mysqld-exporter` | 9104 | `MYSQL_EXPORTER_PASSWORD` (demandé), `MYSQL_EXPORTER_USER` (`exporter`), `MYSQL_ROOT_PASSWORD` |
| `keepalived_exporter.sh` | `keepalived_exporter` | 9165 | `KEEPALIVED_PID_PATH` (`/var/run/keepalived.pid`) |

Communes à tous : `VERSION` (obligatoire, sans le `v`, tag de release GitHub de l'exporter :
le script affiche le lien s'il est lancé sans) et `PORT`.

Les noms de services sont ceux des anciens scripts : relancer un script sur un serveur
déjà équipé remplace l'ancienne installation.

### MySQL

`mysql_exporter.sh` se lance sur le serveur MySQL/MariaDB. Il crée (ou met à jour)
l'utilisateur `exporter@localhost` avec les droits recommandés (`PROCESS, REPLICATION
CLIENT, SELECT`, 3 connexions max), en se connectant en root MySQL par socket ou avec
`MYSQL_ROOT_PASSWORD`. Ses identifiants MySQL sont dans
`/etc/prometheus-exporters/mysqld_exporter.cnf` (`0640 root:prometheus`).

### ⚠️ Keepalived

`keepalived-exporter` (mehdy) **ne gère pas `--web.config.file`** : il n'a pas de basic
auth et ses métriques (états VRRP, compteurs) restent lisibles par tout le réseau. Il
tourne aussi en `root`, car il doit signaler keepalived pour obtenir ses statistiques. Si
c'est un problème : restreindre le port 9165 au serveur Prometheus (pare-feu) ou le
placer derrière un reverse proxy avec authentification.

## Vérifier

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://<hôte>:9100/metrics                       # 401
curl -s -o /dev/null -w '%{http_code}\n' -u prometheus:'<mdp>' http://<hôte>:9100/metrics  # 200
```

Dans Prometheus (`/targets`), les cibles doivent être `UP`.

## node_exporter en conteneur (rôle Ansible)

Le rôle `ansible/roles/node_exporter` lance node_exporter en conteneur **sans** basic auth.
Pour l'activer à la main, déposer un `web.yml` (modèle : `exporter/web.yml.example`) sur
l'hôte, puis dans `ansible/roles/node_exporter/templates/compose.yml.j2` :

```yaml
    command:
      - '--path.rootfs=/host'
      - '--web.config.file=/etc/prometheus-exporters/web.yml'
    volumes:
      - '/:/host:ro,rslave'
      - '/etc/prometheus-exporters/web.yml:/etc/prometheus-exporters/web.yml:ro'
```

## TLS (optionnel)

1. Ajouter `tls_server_config` (certificat + clé) dans `web.yml`.
2. Dans `prometheus/prometheus.yml.tmpl`, ajouter au job concerné :

   ```yaml
   scheme: https
   tls_config:
     ca_file: /etc/prometheus/ca.crt   # à monter dans compose.yml
   ```
