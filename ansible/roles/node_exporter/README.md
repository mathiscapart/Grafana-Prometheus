# Rôle `node_exporter`

Déploie node_exporter en conteneur (réseau et PID de l'hôte, `/` monté en lecture seule)
avec Docker Compose.

Prérequis : Docker et le plugin Compose (rôle `docker`), collection `community.docker`.

## Variables

| Variable | Défaut | Description |
|---|---|---|
| `node_exporter_version` | **obligatoire** | Tag de l'image `quay.io/prometheus/node-exporter` |
| `node_exporter_dir` | `/opt/node_exporter` | Répertoire du compose sur l'hôte |

## Exemple

```yaml
- hosts: node_exporter
  become: true
  roles:
    - role: node_exporter
      vars:
        node_exporter_version: vX.Y.Z
```
