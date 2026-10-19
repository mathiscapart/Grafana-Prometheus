# syntax=docker/dockerfile:1
# Grafana officiel + configuration provisionnée : grafana.ini, datasources, dashboards locaux
# et dashboards grafana.com téléchargés par ID (grafana/dashboards.txt).
# Contexte de build : le dossier grafana/ du repo.
ARG GRAFANA_VERSION

FROM grafana/grafana:${GRAFANA_VERSION} AS dashboards
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
COPY dashboards.txt /tmp/dashboards.txt
# Les références « ${DS_…} » (inputs d'import grafana.com) pointent vers la datasource
# provisionnée d'uid « prometheus », comme le ferait l'écran d'import de l'UI.
RUN while read -r id revision folder; do \
        case "$id" in ''|'#'*) continue ;; esac; \
        mkdir -p "/tmp/dashboards/$folder"; \
        curl -fsSL --retry 3 "https://grafana.com/api/dashboards/$id/revisions/$revision/download" \
            | sed -E 's/\$\{DS_[^}]+\}/prometheus/g' > "/tmp/dashboards/$folder/$id.json"; \
    done < /tmp/dashboards.txt

FROM grafana/grafana:${GRAFANA_VERSION}
COPY grafana.ini /etc/grafana/grafana.ini
COPY provisioning/ /etc/grafana/provisioning/
COPY --from=dashboards /tmp/dashboards/ /etc/grafana/dashboards/
COPY dashboards/ /etc/grafana/dashboards/
