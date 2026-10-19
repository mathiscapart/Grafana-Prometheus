# syntax=docker/dockerfile:1
# Prometheus officiel + envsubst et bcrypt-tool. Au démarrage :
# - le mot de passe PROMETHEUS_BASIC_AUTH_PASSWORD est haché (PROMETHEUS_BASIC_AUTH_PASSWORD_HASH) ;
# - prometheus.yml.tmpl et web.yml.tmpl sont rendus avec les variables d'environnement.
ARG PROMETHEUS_VERSION
FROM prom/prometheus:${PROMETHEUS_VERSION}

# « tools » : contexte de build fourni par compose (image docker/tools)
COPY --from=tools / /

ENTRYPOINT ["/bin/sh", "-c", "PROMETHEUS_BASIC_AUTH_PASSWORD_HASH=$(bcrypt-tool hash \"$PROMETHEUS_BASIC_AUTH_PASSWORD\") && export PROMETHEUS_BASIC_AUTH_PASSWORD_HASH && envsubst < /etc/prometheus/prometheus.yml.tmpl > /etc/prometheus/prometheus.yml && envsubst < /etc/prometheus/web.yml.tmpl > /etc/prometheus/web.yml && exec /bin/prometheus \"$@\"", "--"]
CMD ["--config.file=/etc/prometheus/prometheus.yml", "--web.config.file=/etc/prometheus/web.yml", "--storage.tsdb.path=/prometheus"]
