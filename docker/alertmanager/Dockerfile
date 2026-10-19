# syntax=docker/dockerfile:1
# Alertmanager officiel + envsubst : au démarrage, alertmanager.yml.tmpl est rendu
# avec les variables d'environnement vers alertmanager.yml.
ARG ALERTMANAGER_VERSION
FROM prom/alertmanager:${ALERTMANAGER_VERSION}

# « envsubst » : contexte de build fourni par compose (image docker/envsubst)
COPY --from=envsubst / /

ENTRYPOINT ["/bin/sh", "-c", "envsubst < /etc/alertmanager/alertmanager.yml.tmpl > /etc/alertmanager/alertmanager.yml && exec /bin/alertmanager \"$@\"", "--"]
CMD ["--config.file=/etc/alertmanager/alertmanager.yml", "--storage.path=/alertmanager"]
