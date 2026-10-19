# syntax=docker/dockerfile:1
# Image builder : outils compilés en statique, seuls dans une image scratch, copiés dans
# les images Prometheus et Alertmanager :
# - envsubst (gomodules.xyz/envsubst) : rend les templates de configuration ;
# - bcrypt-tool (github.com/shoenig/bcrypt-tool) : hache le mot de passe basic auth de Prometheus.
ARG GO_VERSION

FROM golang:${GO_VERSION}-alpine AS build
ARG ENVSUBST_VERSION
ARG BCRYPT_TOOL_VERSION
RUN CGO_ENABLED=0 go install gomodules.xyz/envsubst/cmd/envsubst@${ENVSUBST_VERSION} \
    && CGO_ENABLED=0 go install github.com/shoenig/bcrypt-tool@${BCRYPT_TOOL_VERSION}

FROM scratch
COPY --from=build /go/bin/envsubst /go/bin/bcrypt-tool /bin/
