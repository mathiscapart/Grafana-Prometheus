# Rôle `monitoring`

Déploie la stack du repo (Prometheus, Alertmanager, Blackbox, Grafana) avec Docker Compose :
copie les fichiers et le `.env`, génère les targets, construit les images et démarre la stack.

Prérequis : Docker et le plugin Compose (rôle `docker`), collection `community.docker`.

## Variables

| Variable | Défaut | Description |
|---|---|---|
| `monitoring_dir` | `/opt/monitoring` | Répertoire de la stack sur le serveur |
| `monitoring_repo_dir` | racine du repo | Source des fichiers déployés |
| `monitoring_env_file` | `<repo>/.env` | `.env` copié sur le serveur (`0600`) |
| `monitoring_files` | compose, docker, templates, rules… | Fichiers et dossiers déployés |
| `monitoring_prometheus_targets` | `{}` | `{ job: [cibles] }` → `prometheus/targets/<job>.json` |

Un job absent de `monitoring_prometheus_targets` n'est pas touché : son fichier de targets
peut être géré à la main sur le serveur.

## Comportement

- Fichiers modifiés (templates, rules, configs) → la stack est redémarrée (handler),
  ce qui re-rend les templates.
- Fichiers retirés du repo (ex. une rule supprimée) → supprimés du serveur, puis redémarrage.
  `prometheus/targets/` n'est pas concerné : les targets gérées à la main sont conservées.
- `.env` modifié → compose recrée les conteneurs concernés.
- Targets modifiées → relues à chaud par Prometheus.

## Exemple

```yaml
- hosts: monitoring
  become: true
  roles:
    - role: monitoring
      vars:
        monitoring_prometheus_targets:
          node: ["192.168.1.10:9100"]
          blackbox: ["https://example.com/"]
```
