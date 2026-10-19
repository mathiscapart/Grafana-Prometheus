# Déploiement avec Ansible

```
ansible/
├── ansible.cfg                  inventaire, roles_path, options SSH
├── requirements.yml             collections nécessaires (community.docker)
├── inventory/
│   ├── hosts.yml.example        modèle : hôtes et variables propres au déploiement
│   ├── hosts.yml                votre inventaire (non versionné)
│   └── group_vars/
│       └── monitoring.yml       variables communes du groupe monitoring (targets)
├── playbooks/
│   ├── site.yml                 tout : docker → monitoring → node_exporter
│   ├── docker.yml
│   ├── monitoring.yml
│   └── node_exporter.yml
└── roles/
    ├── docker/                  Docker Engine + plugin Compose (Debian, Ubuntu)
    ├── monitoring/              stack Prometheus, Alertmanager, Blackbox, Grafana
    └── node_exporter/           node_exporter en conteneur
```

Chaque rôle suit la structure standard (`defaults/`, `tasks/`, `handlers/`, `templates/`,
`meta/`) et documente ses variables dans son `README.md`. Les variables sont validées
au lancement (`meta/argument_specs.yml`) : une variable obligatoire manquante arrête le
playbook avant toute modification.

## Prérequis

- Machine de contrôle (Linux, macOS ou WSL) : `ansible-core` ≥ 2.15, puis
  `ansible-galaxy collection install -r requirements.yml`.
- Serveurs : Debian ou Ubuntu, accès SSH avec droits root (`become`).
- Un `.env` rempli à la racine du repo (cf. [configuration.md](configuration.md)) : il est
  copié tel quel sur le serveur de monitoring (droits `0600`).

## Lancer

```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml   # puis adapter hôtes et variables
ansible-playbook playbooks/site.yml
```

Exemples :

```bash
ansible-playbook playbooks/monitoring.yml            # seulement la stack
ansible-playbook playbooks/site.yml --limit 192.168.1.10
ansible-playbook playbooks/site.yml --check --diff   # simulation
```

## Où mettre quoi

| Quoi | Où |
|---|---|
| Hôtes, utilisateur SSH, version de node_exporter | `inventory/hosts.yml` |
| Variables communes à un groupe | `inventory/group_vars/<groupe>.yml` |
| Variables propres à un hôte | `inventory/host_vars/<hôte>.yml` |
| Valeurs par défaut d'un rôle | `roles/<rôle>/defaults/main.yml` (ne pas modifier : surcharger dans l'inventaire) |

Variables de chaque rôle : [docker](../ansible/roles/docker/README.md) ·
[monitoring](../ansible/roles/monitoring/README.md) ·
[node_exporter](../ansible/roles/node_exporter/README.md).

## Targets

`inventory/group_vars/monitoring.yml` génère `prometheus/targets/node.json` à partir du
groupe `node_exporter` (port 9100). Pour d'autres jobs :

```yaml
monitoring_prometheus_targets:
  node: "{{ groups['node_exporter'] | default([]) | map('regex_replace', '$', ':9100') | list }}"
  blackbox:
    - https://example.com/
```

Un job absent du dictionnaire n'est pas touché : son fichier peut être géré à la main sur le serveur.
