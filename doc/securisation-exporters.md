# Installation et sécurisation des exporters

Les serveurs n'ont pas de pare-feu : les exporters sont joignables par tout le réseau. Ils
sont donc protégés par **basic auth**, via le fichier `web.yml` de
[exporter-toolkit](https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md)
(`--web.config.file`).

Chaque exporter a ses propres identifiants dans le `.env` :
`<EXPORTER>_BASIC_AUTH_USERNAME` / `<EXPORTER>_BASIC_AUTH_PASSWORD`, avec `<EXPORTER>` =
`NODE`, `MYSQL`, `NGINX` ou `APACHE`. Prometheus les envoie (bloc `basic_auth` de chaque
job dans `prometheus/prometheus.yml.tmpl`) et les scripts d'installation les utilisent pour
générer le `web.yml` de l'exporter.

Les identifiants sont définis **par job** : tous les serveurs d'un même exporter (ex. tous
les node_exporter) partagent le même couple. Un couple par serveur imposerait un job par
serveur dans le template.

Un exporter non déployé ne pose pas de problème : sans fichier `targets/<job>.json`, son job
n'a aucune cible, et ses rules ne se déclenchent pas. Ses variables doivent seulement rester
présentes dans le `.env` (la valeur `XXX` suffit).

## Scripts d'installation

Un script par exporter dans `exporter/`, tous sur le même modèle (`exporter/common.sh`) :

1. installe les prérequis s'il en manque (`curl`, `tar`, `htpasswd`) ;
2. crée l'utilisateur système `prometheus` ;
3. génère `/etc/prometheus-exporters/<exporter>.web.yml` (hash bcrypt, `0640 root:prometheus`) ;
4. télécharge la version demandée (amd64 ou arm64 détecté) dans `/usr/local/bin` ;
5. installe et démarre le service systemd ;
6. vérifie que le service tourne et refuse un accès sans identifiants (`401`).

Copier le dossier `exporter/` sur le serveur, puis :

```bash
sudo NODE_BASIC_AUTH_USERNAME=prometheus VERSION=X.Y.Z ./node_exporter.sh
```

Les identifiants sont **ceux du `.env` de la stack** pour cet exporter. Le mot de passe
est demandé en saisie masquée : ne pas le passer en variable sur la ligne de commande,
il resterait dans l'historique du shell. Relancer le script conserve le `web.yml`
existant ; `WEB_CONFIG_RESET=1` le régénère (par exemple après un changement de mot de
passe dans le `.env`).

Relancer un script met à jour l'exporter (nouvelle `VERSION`) sans autre effet.

| Script | Service systemd | Port | Basic auth | Variables propres (défaut) |
|---|---|---|---|---|
| `node_exporter.sh` | `node_exporter` | 9100 | `NODE_BASIC_AUTH_*` | — |
| `nginx_exporter.sh` | `nginx_exporter` | 9113 | `NGINX_BASIC_AUTH_*` | `NGINX_SCRAPE_URI` (`http://127.0.0.1:8080/nginx_status`, stub_status nginx) |
| `apache_exporter.sh` | `apache_exporter` | 9117 | `APACHE_BASIC_AUTH_*` | `APACHE_SCRAPE_URI` (`http://localhost/server-status?auto`, mod_status) |
| `mysql_exporter.sh` | `mysqld-exporter` | 9104 | `MYSQL_BASIC_AUTH_*` | `MYSQL_EXPORTER_PASSWORD` (demandé ; sans `'`, `\`, `#` ni `;`), `MYSQL_EXPORTER_USER` (`exporter`), `MYSQL_ROOT_PASSWORD` |
| `keepalived_exporter.sh` | `keepalived_exporter` | 9165 | aucune (non supportée) | `KEEPALIVED_PID_PATH` (`/var/run/keepalived.pid`) |

Communes à tous : `VERSION` (obligatoire, sans le `v`, tag de release GitHub de l'exporter :
le script affiche le lien s'il est lancé sans) et `PORT`.

Les noms de services sont ceux des anciens scripts : relancer un script sur un serveur
déjà équipé remplace l'ancienne installation.

### MySQL

`mysql_exporter.sh` se lance sur le serveur MySQL/MariaDB. Il crée (ou met à jour)
l'utilisateur MySQL `exporter@localhost` (à ne pas confondre avec le basic auth) avec les droits recommandés (`PROCESS, REPLICATION
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
      - '--web.config.file=/etc/prometheus-exporters/node_exporter.web.yml'
    volumes:
      - '/:/host:ro,rslave'
      - '/etc/prometheus-exporters/node_exporter.web.yml:/etc/prometheus-exporters/node_exporter.web.yml:ro'
```

## TLS (optionnel)

1. Ajouter `tls_server_config` (certificat + clé) dans le `web.yml` de l'exporter.
2. Dans `prometheus/prometheus.yml.tmpl`, ajouter au job concerné :

   ```yaml
   scheme: https
   tls_config:
     ca_file: /etc/prometheus/ca.crt   # à monter dans compose.yml
   ```
