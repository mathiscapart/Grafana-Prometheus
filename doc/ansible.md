# Déploiement avec Ansible

```
ansible/
├── ansible.cfg              inventaire par défaut : inventory.yml
├── inventory.yml.example    modèle d'inventaire (inventory.yml n'est pas versionné)
├── requirements.yml         collection community.docker
├── site.yml                 playbook principal
└── roles/
    ├── docker/              installe Docker + plugin Compose (Debian)
    ├── monitoring/          déploie la stack (compose, templates, rules, .env, targets)
    └── node_exporter/       déploie node_exporter en conteneur
```

## Prérequis

- Machine de contrôle : `ansible-core` puis `ansible-galaxy collection install -r ansible/requirements.yml`.
- Serveurs : Debian, accès SSH root (ou `become`).
- Un `.env` rempli à la racine du repo (cf. [configuration.md](configuration.md)) :
  il est copié tel quel sur le serveur de monitoring (droits `0600`).

## Lancer

```bash
cd ansible
cp inventory.yml.example inventory.yml   # puis adapter les hôtes
ansible-playbook site.yml
```

Pour un seul rôle : `ansible-playbook site.yml --limit monitoring`.

## Variables

Toutes ont une valeur par défaut (`roles/*/defaults/main.yml`) et se surchargent dans l'inventaire.

| Variable | Défaut | Rôle |
|---|---|---|
| `monitoring_dir` | `/opt/monitoring` | Répertoire de la stack sur le serveur |
| `monitoring_env_file` | `<repo>/.env` | `.env` local copié sur le serveur |
| `monitoring_files` | compose, docker, templates, rules… | Fichiers du repo déployés |
| `monitoring_prometheus_targets` | `{}` | Targets générées, cf. ci-dessous |
| `node_exporter_dir` | `/opt/node_exporter` | Répertoire de node_exporter sur les hôtes |

### Targets

`monitoring_prometheus_targets` génère `prometheus/targets/<job>.json` sur le serveur.
Un job absent du dictionnaire n'est pas touché : son fichier peut être géré à la main.

```yaml
monitoring_prometheus_targets:
  # toutes les machines du groupe node_exporter, port 9100
  node: "{{ groups['node_exporter'] | map('regex_replace', '$', ':9100') | list }}"
  blackbox:
    - https://example.com/
```

## Comportement

- Les fichiers modifiés (templates, rules, `.env`…) entraînent la recréation des conteneurs,
  donc le re-rendu des templates. Sans modification, un nouveau passage ne change rien.
- Les targets sont relues à chaud par Prometheus, sans redémarrage.
- Les images Prometheus/Alertmanager sont construites sur le serveur (`build: always`, avec cache).
