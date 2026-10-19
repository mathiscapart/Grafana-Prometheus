# CI

Workflow GitHub Actions : `.github/workflows/ci.yml`, sur chaque pull request et push sur `main`.

| Job | Étapes |
|---|---|
| `lint` | yamllint · hadolint (`docker/*/Dockerfile`) · shellcheck (`exporter/*.sh`, avec `common.sh`) · `promtool check rules` · `ansible-playbook --syntax-check` + ansible-lint |
| `build-test` | `.env` de CI · `docker compose build` · démarrage (`up --wait`, healthchecks) · configurations rendues validées par `promtool check config` et `amtool check-config` |

## Versions

Les versions des images testées sont dans le bloc `env:` du workflow : ce sont les
seules versions figées du repo. Le job `build-test` vérifie que toute variable de
`.env.example` est renseignée dans le `.env` de CI : ajouter une variable impose de
l'ajouter dans l'étape « Générer le .env de CI ».

## En local

```bash
yamllint .
shellcheck -x -S warning exporter/*.sh
docker compose build && docker compose up -d --wait
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```
