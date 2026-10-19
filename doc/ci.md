# CI

Workflow GitHub Actions : `.github/workflows/ci.yml`, sur chaque pull request et push sur `main`.

| Job | Étapes |
|---|---|
| `lint` | yamllint · hadolint (`docker/*/Dockerfile`) · shellcheck · `promtool check rules` · `ansible-playbook --syntax-check` + ansible-lint |
| `build-test` | `.env` de CI (`tests/ci-env.sh`) · `docker compose build` · `tests/smoke.sh` |
| `ansible-deploy` | déploie les rôles `monitoring` et `node_exporter` sur le runner (`tests/ansible/hosts.yml`), puis rejoue et exige `changed=0` (idempotence) |

`tests/smoke.sh` démarre la stack et vérifie :

- que les configurations rendues par envsubst sont valides (`promtool`, `amtool`) ;
- qu'un node_exporter protégé par `web.yml` refuse l'accès sans authentification ;
- que Prometheus le scrape bien (`UP`) avec les identifiants du `.env` ;
- que les rules sont chargées.

## Versions

Les versions des images testées sont dans le bloc `env:` du workflow : ce sont les
seules versions figées du repo. `tests/ci-env.sh` vérifie que toute variable de
`.env.example` est renseignée dans le `.env` de CI : ajouter une variable impose de
l'ajouter dans ce script.

Le rôle `docker` n'est pas joué en CI (Docker est déjà installé sur le runner) : il est
seulement vérifié par `--syntax-check` et ansible-lint.

## En local

```bash
# configs (Linux/macOS ou WSL)
yamllint .
shellcheck -S warning tests/*.sh exporter/*.sh

# test de fumée — démonte la stack et ses volumes à la fin : pas sur un serveur en production
ENV_FILE=.env NODE_EXPORTER_VERSION=vX.Y.Z bash tests/smoke.sh
```
