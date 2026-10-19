# Grafana

Grafana est construit depuis `docker/grafana/Dockerfile` (contexte : `grafana/`). Toute la
configuration est provisionnée dans l'image : rien à cliquer après un déploiement.

```
grafana/
├── grafana.ini                       surcharge des réglages par défaut
├── dashboards.txt                    dashboards grafana.com à télécharger (par ID)
├── dashboards/<Dossier>/*.json       dashboards locaux (JSON versionnés)
└── provisioning/
    ├── datasources/datasources.yml   Prometheus (défaut) + Alertmanager
    └── dashboards/dashboards.yml     un dossier Grafana par sous-dossier
```

## Dashboards inclus

| Dossier | Dashboard | Source |
|---|---|---|
| Infrastructure | Node Exporter Full (page d'accueil) | grafana.com [1860](https://grafana.com/grafana/dashboards/1860) |
| Services | MySQL Exporter Quickstart and Dashboard | grafana.com [14057](https://grafana.com/grafana/dashboards/14057) |
| Services | NGINX exporter (officiel nginx-prometheus-exporter) | grafana.com [12708](https://grafana.com/grafana/dashboards/12708) |
| Services | Keepalived Exporter (mehdy/keepalived-exporter) | local `dashboards/Services/keepalived.json` |
| Monitoring | Blackbox Exporter (HTTP prober) | grafana.com [13659](https://grafana.com/grafana/dashboards/13659) |
| Monitoring | Prometheus 2.0 Overview | grafana.com [3662](https://grafana.com/grafana/dashboards/3662) |
| Monitoring | Alertmanager | grafana.com [9578](https://grafana.com/grafana/dashboards/9578) |

Prometheus scrape aussi Alertmanager, le blackbox exporter et Grafana : la stack se
surveille elle-même (dashboards Monitoring, alerte `TargetDown`).

## Importer un dashboard grafana.com par son ID

**Depuis l'interface** (test ponctuel) : *Dashboards → New → Import*, saisir l'ID (ex.
`1860`) dans le champ *Find and import dashboards…*, *Load*, puis choisir la datasource
Prometheus. Pas besoin de télécharger le JSON.

**Dans le projet** (conservé à chaque déploiement) : ajouter une ligne à `grafana/dashboards.txt` :

```
# <id>   <révision|latest>   <dossier Grafana>
1860     45                  Infrastructure
```

puis `docker compose up -d --build grafana`.

Au build, le JSON est téléchargé depuis `https://grafana.com/api/dashboards/<id>/revisions/<révision>/download`
et ses références `${DS_…}` (les « inputs » que l'écran d'import demande de choisir) sont
pointées sur la datasource Prometheus provisionnée (uid `prometheus`).

- La **révision** figée garantit le même dashboard à chaque build ; `latest` prend la
  dernière (visible sur la page du dashboard, onglet *Revisions*).
- Le dossier Grafana est créé automatiquement.
- Choisir un dashboard : vérifier qu'il vise le bon exporter (noms des métriques) et
  qu'il n'est pas spécifique à Kubernetes (variables `cluster`, `pod`, `namespace`).
  Les anciens panneaux Angular (`graph`, `singlestat`) sont migrés automatiquement par Grafana.

## Dashboards locaux

Pour un dashboard maison ou modifié : l'exporter en JSON (*Share → Export → Save to file*,
sans cocher *Export for sharing externally*), le placer dans `grafana/dashboards/<Dossier>/`,
puis `docker compose up -d --build grafana`.

Les dashboards provisionnés ne sont pas modifiables dans l'UI (`allowUiUpdates: false`) :
le repo reste la source de vérité. Pour expérimenter, *Save as* crée une copie libre.

## Réglages (`grafana.ini`)

Inscription et création d'organisation désactivées, accès anonyme désactivé, pas de
télémétrie, de fil d'actualités ni de Gravatar, cookies `SameSite=strict`, page d'accueil
sur Node Exporter Full. Toute option de la
[configuration Grafana](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
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
