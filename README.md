# 3MIN

Nous devons monitorer l'infrastructure Dundermifflin, pour ce faire nous utilisons des solutions open source, notamment la suite Grafana + Prometheus.
## 📦 Services utilisés

| Service                     | Description                                                             |
|-----------------------------|-------------------------------------------------------------------------|
| **Prometheus**              | Collecte les métriques via différents exporters.                        |
| **Grafana**                 | Visualisation des métriques via des dashboards.                         |
| **Node Exporter**           | Suivi des ressources système (CPU, RAM, disque).                        |
| **Blackbox Exporter**       | Vérification de la disponibilité de sites ou services via HTTP/ICMP/TCP. |
| **Keepalived Exporter**     | Suivi des états de basculement (VRRP).                                  |
| **Nginx / Apache Exporter** | Suivi des métriques des serveurs web.                                   |
| **Mysqld Exporter**         | Suivi des métriques de la base de donnée.                               |

# ✨ Prérequis

- Copier ``.env.example`` en ``.env`` et remplacer chaque ``XXX`` (versions, webhook Discord, identifiants).
- Renseigner les targets de chaque exporter dans ``prometheus/targets/<job>.json`` (modèle : ``node.json.example``).
- Sécuriser les exporters avec un ``web.yml`` (modèle : ``exporter/web.yml.example``).

- Pour déployer vos `` exporters`` sur vos serveurs, vous pouvez utiliser les commandes ci-dessous :
````bash
# Exemple (ajustez selon votre script)
cd exporter
./install_node_exporter.sh
./install_apache_exporter.sh
# etc.
````


⚠️ N'oubliez pas d'initialiser les variables dans les scripts, qui se trouvent dans le dossier exporter

La documentation détaillée est dans le dossier [`doc/`](doc) :

- [Configuration (.env, templates, targets, rules)](doc/configuration.md)
- [Alertmanager → Discord](doc/alertmanager-discord.md)
- [Grafana (configuration, import de dashboards)](doc/grafana.md)
- [Sécurisation des exporters (web.yml)](doc/securisation-exporters.md)
- [Déploiement avec Ansible](doc/ansible.md)
- [CI (lint, build, tests)](doc/ci.md)

## 🧱 Lancé le projet

L'ensemble des services est déployé via Docker Compose, lancé cette commande à la racine du projet  : 
```bash
docker compose up -d --build
``` 
Les métriques sont accessibles via Prometheus, et visualisées avec Grafana sur votre pc en allant sur `localhost:3000` pour Grafana et `localhost:9090` pour Prometheus.
    
## Schéma d'infrastructure avec monitoring
![img.png](img/schema.drawio.png)

## 🔄 Mise à jour

Ajouter ou modifier des targets dans ``prometheus/targets/*.json`` : Prometheus les recharge automatiquement.
Pour le reste (``.env``, templates, rules), voir [doc/configuration.md](doc/configuration.md#appliquer-une-modification).
