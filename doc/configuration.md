# Configuration du projet

## Démarrage rapide

```bash
cp .env.example .env                                  # puis remplacer chaque XXX
cp prometheus/targets/node.json.example prometheus/targets/node.json   # puis mettre vos IP
docker compose up -d --build
```

## Ce qui se configure où

| Quoi | Où | Versionné |
|---|---|---|
| Versions des images, secrets, identifiants | `.env` | non (`.env.example` sert de modèle) |
| Jobs de scrape Prometheus | `prometheus/prometheus.yml.tmpl` | oui |
| Cibles (IP:port) de chaque job | `prometheus/targets/<job>.json` | non (`*.json.example` sert de modèle) |
| Règles d'alerte | `prometheus/rules/*.rules.yml` | oui |
| Routage et receivers des alertes | `alertmanager/alertmanager.yml.tmpl` | oui |
| Modules blackbox | `blackbox/blackbox.yml` | oui |
| Grafana : réglages, datasources, dashboards | `grafana/` ([doc](grafana.md)) | oui |
| Authentification / TLS des exporters | `web.yml` sur chaque hôte exporter | non (`exporter/web.yml.example`) |

Le `.env` porte les valeurs qui changent d'un déploiement à l'autre (versions, secrets).
Les cibles et les règles restent dans des fichiers dédiés : plus lisibles et plus simples
à maintenir qu'une liste d'IP dans une variable d'environnement.

## Variables du `.env`

| Variable | Rôle |
|---|---|
| `PROMETHEUS_VERSION`, `ALERTMANAGER_VERSION`, `BLACKBOX_VERSION`, `GRAFANA_VERSION` | Tag Docker Hub de chaque image |
| `GO_VERSION` | Tag de l'image `golang:<GO_VERSION>-alpine` qui compile les outils |
| `ENVSUBST_VERSION` | Tag de [gomodules.xyz/envsubst](https://github.com/gomodules/envsubst) (ex. `v0.2.0`) |
| `BCRYPT_TOOL_VERSION` | Tag de [shoenig/bcrypt-tool](https://github.com/shoenig/bcrypt-tool) (ex. `v1.1.11`) |
| `PROMETHEUS_BASIC_AUTH_USERNAME`, `PROMETHEUS_BASIC_AUTH_PASSWORD` | Basic auth de Prometheus (interface et API), aussi utilisé par Grafana ([voir ci-dessous](#accès-aux-services)) |
| `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD` | Compte admin Grafana (créé au premier démarrage, [doc](grafana.md)) |
| `GF_SERVER_ROOT_URL` | URL publique de Grafana |
| `DISCORD_WEBHOOK_URL` | Webhook Discord des alertes ([doc](alertmanager-discord.md)) |
| `<EXPORTER>_BASIC_AUTH_USERNAME`, `<EXPORTER>_BASIC_AUTH_PASSWORD` | Basic auth de chaque exporter, `<EXPORTER>` = `NODE`, `MYSQL`, `NGINX`, `APACHE` ([doc](securisation-exporters.md)) |

Toutes ces variables sont obligatoires : `docker compose` refuse de démarrer si l'une
d'elles est absente.

⚠️ **Caractère `$`** : Docker Compose interprète les `$` du `.env`. Une valeur qui en
contient doit être entre apostrophes (`PASSWORD='Ab$cd'`), sinon elle est tronquée sans
erreur (`Ab`) : identifiants refusés, cibles `DOWN`. Les apostrophes sont interdites dans
les valeurs. Pour éviter tout caractère spécial : `openssl rand -hex 24`.

## Accès aux services

| Service | Port publié | Accès |
|---|---|---|
| Grafana | 3000 | compte admin du `.env` |
| Prometheus | 9090 | basic auth `PROMETHEUS_BASIC_AUTH_*` |
| Alertmanager, Blackbox | aucun | réseau interne Docker uniquement (via Grafana, ou `docker compose exec`) |

Au démarrage de Prometheus, `PROMETHEUS_BASIC_AUTH_PASSWORD` est haché (bcrypt) et
`prometheus/web.yml.tmpl` est rendu en `web.yml`. Ce template accepte toutes les options
du [fichier web de Prometheus](https://prometheus.io/docs/prometheus/latest/configuration/https/)
(TLS notamment). Le basic auth passe en clair sur le réseau sans TLS.

## Templates et envsubst

```
docker/tools/Dockerfile         golang:<GO_VERSION>-alpine : go install envsubst et bcrypt-tool (statiques)
        │                       → image scratch : les deux binaires seuls
        ├──▶ docker/prometheus/Dockerfile     prom/prometheus:<PROMETHEUS_VERSION>
        └──▶ docker/alertmanager/Dockerfile   prom/alertmanager:<ALERTMANAGER_VERSION>
```

1. L'image builder `tools` compile [gomodules.xyz/envsubst](https://github.com/gomodules/envsubst)
   et [bcrypt-tool](https://github.com/shoenig/bcrypt-tool) en binaires statiques
   (`CGO_ENABLED=0`) et ne garde qu'eux (image `scratch`).
2. Les Dockerfiles Prometheus et Alertmanager copient ces binaires dans l'image officielle
   (`COPY --from=tools`). Compose fournit l'image builder comme contexte de build
   nommé (`additional_contexts: tools: service:tools`) ; le service `tools` a
   `scale: 0` : il est construit mais aucun conteneur n'est créé. Testé avec Docker
   Compose 2.38 et 5.6 (un service placé dans un profil inactif n'est pas utilisable
   comme contexte de build avec Compose 2.x).
3. À **chaque démarrage** du conteneur, l'`ENTRYPOINT` rend les `.tmpl` en `.yml` avec les
   variables d'environnement puis lance le service (Prometheus hache d'abord son mot de passe
   basic auth).

### Ajouter une variable dans un template

1. L'écrire dans le template : `${MA_VARIABLE}`.
2. La déclarer dans `environment:` du service concerné dans `compose.yml` :
   `MA_VARIABLE: ${MA_VARIABLE:?à définir dans .env}`.
3. L'ajouter dans `.env.example` (valeur `XXX`) et dans votre `.env`.

Seules les variables listées dans `environment:` entrent dans le conteneur : le mot de
passe Grafana, par exemple, n'est jamais visible par Prometheus.

À savoir (syntaxe bash) :

- `${VAR}` est remplacé par la valeur, `${VAR:-défaut}` donne une valeur par défaut ;
- une variable **non définie dans le conteneur est remplacée par une chaîne vide**, sans
  erreur (même avec `${VAR:?…}`) : c'est le `:?` de `compose.yml` qui garantit qu'elle est renseignée ;
- `$1`, `$2`… restent intacts : les `replacement: $1` des `relabel_configs` sont préservés ;
- pour un `$` littéral, écrire `$$` ;
- les valeurs sont entourées de `'…'` dans les templates : elles ne doivent pas contenir d'apostrophe.

### Appliquer une modification

| Modification | Commande |
|---|---|
| `.env` | `docker compose up -d` (recrée les conteneurs concernés) |
| `*.tmpl` | `docker compose restart prometheus alertmanager` (le template est re-rendu au démarrage) |
| `prometheus/targets/*.json` | rien : Prometheus relit les fichiers automatiquement |
| `prometheus/rules/*.rules.yml` | `docker compose restart prometheus` |
| `docker/*/Dockerfile`, versions dans `.env` | `docker compose up -d --build` |

Pour voir la configuration réellement rendue :

```bash
docker compose exec prometheus cat /etc/prometheus/prometheus.yml
```

## Targets

Chaque job de `prometheus.yml.tmpl` lit ses cibles dans `prometheus/targets/<job>.json`
(format [file_sd](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#file_sd_config)).
Un fichier absent ne provoque pas d'erreur : le job n'a simplement aucune cible.

```json
[
  {
    "labels": { "env": "production" },
    "targets": ["192.168.1.10:9100", "192.168.1.11:9100"]
  }
]
```

### Blackbox

Le job `blackbox` sonde des URL ou des `hôte:port` via le blackbox exporter
(modèle : `prometheus/targets/blackbox.json.example`). Le module utilisé est `http_2xx`
par défaut ; un groupe de cibles peut en choisir un autre avec le label `__param_module` :

```json
[
  { "targets": ["https://example.com/"] },
  { "labels": { "__param_module": "tcp_connect" }, "targets": ["192.168.1.20:5432"] }
]
```

Les modules disponibles sont définis dans `blackbox/blackbox.yml` (`http_2xx`, `tcp_connect`) ;
pour en ajouter un, voir la [documentation blackbox](https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md)
puis `docker compose restart blackbox`.

### Ajouter un nouveau type d'exporter

1. Ajouter un job dans `prometheus/prometheus.yml.tmpl` sur le modèle des autres
   (`basic_auth` + `file_sd_configs` pointant sur `targets/<job>.json`).
2. Créer `prometheus/targets/<job>.json` (et un `<job>.json.example` si le job est partagé).
3. Ajouter ses règles dans `prometheus/rules/<job>.rules.yml`.
4. `docker compose restart prometheus` (ou `docker compose up -d` si de nouvelles variables
   ont été ajoutées dans `compose.yml`).

## Rules

Les fichiers `prometheus/rules/*.rules.yml` sont chargés automatiquement. Les règles d'un
exporter sans cible ne déclenchent rien : elles peuvent rester en place.

| Fichier | Alertes |
|---|---|
| `target.rules.yml` | `TargetDown` : une cible ne répond plus |
| `monitoring.rules.yml` | La stack elle-même : rechargement de config raté (Prometheus, Alertmanager), rules en erreur, Prometheus sans Alertmanager, notifications en échec (ex. webhook Discord invalide) |
| `node.rules.yml` | CPU > 85 %, RAM et disque > 90 %, disque plein dans moins de 24 h (prédiction sur 6 h), OOM kill, horloge NTP non synchronisée, redémarrage |
| `blackbox.rules.yml` | Site injoignable, certificat TLS expirant dans moins de 14 jours (warning) ou de 3 jours (critical) |
| `mysql.rules.yml` | MySQL down, connexions > 80 % de `max_connections`, réplication arrêtée (threads IO/SQL), retard de réplication > 30 s, redémarrage |
| `nginx.rules.yml`, `apache.rules.yml` | Serveur web down |
| `keepalived.rules.yml` | Keepalived down, bascule MASTER/BACKUP |

Sévérités : `critical` (action immédiate), `warning` (à traiter), `info` (pour information,
ex. redémarrage). Toutes partent sur Discord ; le routage par sévérité se règle dans
`alertmanager/alertmanager.yml.tmpl` (cf. [alertmanager-discord.md](alertmanager-discord.md)).

Les règles de réplication MySQL ne concernent que les réplicas : un serveur sans
réplication ne déclenche rien. Pour tester une règle avant de la déployer :
`promtool check rules` (syntaxe) et
[`promtool test rules`](https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/)
(comportement sur des séries simulées).
