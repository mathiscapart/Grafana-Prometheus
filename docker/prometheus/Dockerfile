# syntax=docker/dockerfile:1
# Prometheus officiel + envsubst : au démarrage, prometheus.yml.tmpl est rendu
# avec les variables d'environnement vers prometheus.yml.
ARG PROMETHEUS_VERSION
FROM prom/prometheus:${PROMETHEUS_VERSION}

# « envsubst » : contexte de build fourni par compose (image docker/envsubst)
COPY --from=envsubst / /

ENTRYPOINT ["/bin/sh", "-c", "envsubst < /etc/prometheus/prometheus.yml.tmpl > /etc/prometheus/prometheus.yml && exec /bin/prometheus \"$@\"", "--"]
CMD ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus"]
