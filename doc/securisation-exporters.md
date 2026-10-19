# Sécurisation des exporters (`web.yml`)

Les exporters officiels (node, mysqld, nginx, apache, blackbox…) reposent sur
[exporter-toolkit](https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md)
et acceptent un fichier `--web.config.file` qui active l'authentification basique et/ou le TLS.

`web.yml` contient des secrets propres à chaque déploiement : il n'est **pas versionné**
(`.gitignore`). Le modèle est `exporter/web.yml.example`.

## 1. Choisir les identifiants

Dans `.env` :

```dotenv
EXPORTER_BASIC_AUTH_USERNAME=prometheus
EXPORTER_BASIC_AUTH_PASSWORD=un-mot-de-passe-long
```

Prometheus les utilise pour scraper tous les jobs d'exporters (`basic_auth` dans
`prometheus/prometheus.yml.tmpl`).

## 2. Générer le hash bcrypt du mot de passe

```bash
htpasswd -nBC 10 "" | tr -d ':\n'          # paquet apache2-utils / httpd-tools
# ou
python3 -c 'import bcrypt; print(bcrypt.hashpw(b"un-mot-de-passe-long", bcrypt.gensalt()).decode())'
```

## 3. Créer `web.yml` sur chaque hôte exporter

```bash
cp exporter/web.yml.example /etc/exporter/web.yml
```

```yaml
basic_auth_users:
  prometheus: '$2y$10$...'   # utilisateur = EXPORTER_BASIC_AUTH_USERNAME
```

```bash
chmod 640 /etc/exporter/web.yml   # lisible par l'utilisateur de l'exporter uniquement
```

## 4. Lancer l'exporter avec le fichier

Ajouter `--web.config.file=/etc/exporter/web.yml` à la ligne `ExecStart` du service systemd :

```ini
ExecStart=/usr/local/bin/node_exporter --web.config.file=/etc/exporter/web.yml
```

Puis `systemctl daemon-reload && systemctl restart node_exporter`.

En Docker (ex. `ansible/roles/node_exporter/templates/compose.yml.j2`) :

```yaml
    command:
      - '--path.rootfs=/host'
      - '--web.config.file=/etc/exporter/web.yml'
    volumes:
      - '/:/host:ro,rslave'
      - '/etc/exporter/web.yml:/etc/exporter/web.yml:ro'
```

> `keepalived-exporter` (mehdy) n'est pas un exporter officiel : vérifier dans son
> `--help` qu'il supporte `--web.config.file` avant de l'utiliser.

## 5. Vérifier

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://<hôte>:9100/metrics                      # 401
curl -s -o /dev/null -w '%{http_code}\n' -u prometheus:<mdp> http://<hôte>:9100/metrics  # 200
```

Dans Prometheus (`/targets`), la cible doit être `UP`.

## TLS (optionnel)

1. Décommenter `tls_server_config` dans `web.yml` et fournir certificat + clé.
2. Dans `prometheus/prometheus.yml.tmpl`, ajouter au job concerné :

   ```yaml
   scheme: https
   tls_config:
     ca_file: /etc/prometheus/ca.crt   # à monter dans compose.yml
   ```
