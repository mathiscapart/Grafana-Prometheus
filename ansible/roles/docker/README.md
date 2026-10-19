# Rôle `docker`

Installe Docker Engine et le plugin Compose depuis le dépôt APT officiel (Debian, Ubuntu).

## Variables

| Variable | Défaut | Description |
|---|---|---|
| `docker_apt_distribution` | distribution de l'hôte | `debian` ou `ubuntu` |
| `docker_apt_url` | `https://download.docker.com/linux/<distribution>` | Dépôt APT |
| `docker_packages` | engine, CLI, containerd, buildx, compose | Paquets installés |

## Exemple

```yaml
- hosts: all
  become: true
  roles:
    - docker
```
