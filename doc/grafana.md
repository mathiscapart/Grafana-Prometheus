# Grafana

Image officielle `grafana/grafana`, configurée par des fichiers montés depuis `grafana/` :

```
grafana/
├── grafana.ini                       surcharge des réglages par défaut
├── dashboards.txt                    dashboards grafana.com recommandés (à importer à la main)
├── dashboards/<Dossier>/*.json       dashboards provisionnés (JSON versionnés)
└── provisioning/
    ├── datasources/datasources.yml   Prometheus (défaut) + Alertmanager
    └── dashboards/dashboards.yml     un dossier Grafana par sous-dossier de dashboards/
```

Une modification de ces fichiers s'applique avec `docker compose restart grafana`.

## Importer un dashboard grafana.com

`grafana/dashboards.txt` liste les dashboards recommandés pour les exporters du projet
(Node Exporter Full, MySQL, NGINX, Blackbox, Prometheus, Alertmanager). Pour en importer un :

1. *Dashboards → New → Import* ;
2. saisir l'ID (ex. `1860`) dans *Find and import dashboards…*, puis *Load* ;
3. choisir le dossier et la datasource **Prometheus**, puis *Import*.

Le dashboard est enregistré dans la base de Grafana (volume `graf_data`) : il survit aux
redémarrages, mais pas à la suppression du volume.

Pour choisir un autre dashboard sur [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards) :
vérifier qu'il vise le bon exporter (noms des métriques) et qu'il n'est pas spécifique à
Kubernetes (variables `cluster`, `pod`, `namespace`). Les anciens panneaux (`graph`,
`singlestat`) sont migrés automatiquement par Grafana.

## Dashboards provisionnés

Les JSON de `grafana/dashboards/<Dossier>/` sont chargés au démarrage, dans le dossier
Grafana du même nom (actuellement : `Services/keepalived.json`). Pour versionner un
dashboard : *Export → Export as JSON* (sans *Export for sharing externally*), placer le
fichier dans `grafana/dashboards/<Dossier>/`, puis `docker compose restart grafana`.

Ils ne sont pas modifiables dans l'UI (`allowUiUpdates: false`) : le repo reste la source
de vérité. Pour expérimenter, *Save as* crée une copie libre.

## Réglages (`grafana.ini`)

Inscription et création d'organisation désactivées, accès anonyme désactivé, pas de
télémétrie, de fil d'actualités ni de Gravatar, cookies `SameSite=strict`. Toute option de
la [configuration Grafana](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
peut y être ajoutée.

Le `.env` fournit :

| Variable | Rôle |
|---|---|
| `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD` | Compte admin |
| `GF_SERVER_ROOT_URL` | URL publique (liens, redirections) |

⚠️ Le compte admin n'est créé qu'au **premier démarrage** (volume `graf_data` vide).
Changer ensuite le mot de passe dans le `.env` n'a pas d'effet ; utiliser :

```bash
docker compose exec grafana grafana cli admin reset-admin-password '<nouveau>'
```

## Supervision de la stack

Prometheus scrape aussi Alertmanager, le blackbox exporter et Grafana : les dashboards
Prometheus et Alertmanager ont des données, et l'alerte `TargetDown` couvre la stack elle-même.
