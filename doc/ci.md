# CI

Workflow GitHub Actions : `.github/workflows/ci.yml`, sur chaque pull request et push sur `main`.

| Job | Étapes |
|---|---|
| `lint` | yamllint · hadolint (`docker/*/Dockerfile`) · shellcheck · `promtool check rules` · `ansible-playbook --syntax-check` + ansible-lint |
| `build-test` | génère un `.env` de CI · `docker compose build` · `tests/smoke.sh` |

`tests/smoke.sh` démarre la stack et vérifie :

- que les configurations rendues par envsubst sont valides (`promtool`, `amtool`) ;
- qu'un node_exporter protégé par `web.yml` refuse l'accès sans authentification ;
- que Prometheus le scrape bien (`UP`) avec les identifiants du `.env` ;
- que les rules sont chargées.

## Versions

Les versions des images testées sont dans le bloc `env:` du workflow : ce sont les
seules versions figées du repo. Le job vérifie aussi que toute variable de
`.env.example` est renseignée dans le `.env` de CI : ajouter une variable impose de
l'ajouter au workflow.

## En local

```bash
# configs (Linux/macOS ou WSL)
yamllint .
shellcheck -S warning tests/*.sh exporter/*.sh

# test de fumée — démonte la stack et ses volumes à la fin : pas sur un serveur en production
ENV_FILE=.env NODE_EXPORTER_VERSION=vX.Y.Z bash tests/smoke.sh
```
