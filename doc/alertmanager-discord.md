# Alertmanager → Discord

Alertmanager envoie les alertes vers un salon Discord via le receiver natif
[`discord_configs`](https://prometheus.io/docs/alerting/latest/configuration/#discord_config).

## Créer le webhook

1. Discord → paramètres du salon → **Intégrations** → **Webhooks** → **Nouveau webhook**.
2. Copier l'URL (`https://discord.com/api/webhooks/<id>/<token>`).
3. La renseigner dans `.env` :

   ```dotenv
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/<id>/<token>
   ```

4. `docker compose up -d alertmanager`.

L'URL contient le token du webhook : c'est un secret, elle ne doit vivre que dans `.env`.

## Personnaliser

Le routage se modifie dans `alertmanager/alertmanager.yml.tmpl` (format standard Alertmanager,
rendu par envsubst — cf. [configuration.md](configuration.md#templates-et-envsubst)).

Exemple : envoyer les alertes `critical` dans un second salon.

```yaml
route:
  receiver: discord
  routes:
    - matchers: [severity="critical"]
      receiver: discord-critical

receivers:
  - name: discord
    discord_configs:
      - webhook_url: '${DISCORD_WEBHOOK_URL}'
        send_resolved: true
  - name: discord-critical
    discord_configs:
      - webhook_url: '${DISCORD_CRITICAL_WEBHOOK_URL}'
        send_resolved: true
```

Penser à déclarer `DISCORD_CRITICAL_WEBHOOK_URL` dans `environment:` du service
`alertmanager` (`compose.yml`) et dans `.env.example`.

## Tester

```bash
docker compose exec alertmanager amtool alert add test severity=warning \
  --annotation=summary="Test Discord" --alertmanager.url=http://localhost:9093
```

Le message arrive dans le salon après `group_wait` (30 s).
