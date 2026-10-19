# syntax=docker/dockerfile:1
# Image builder : envsubst (paquet Alpine gettext-envsubst) et ses bibliothèques musl,
# seuls dans une image scratch, prêts à être copiés dans les images Prometheus et Alertmanager.
ARG GO_VERSION

FROM golang:${GO_VERSION}-alpine AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
# Le binaire et les bibliothèques listées par ldd sont recopiés dans /out (liens résolus).
RUN apk add --no-cache gettext-envsubst \
    && mkdir /out \
    && ldd /usr/bin/envsubst | grep -o '/[^ ]*' | xargs tar -ch /usr/bin/envsubst | tar -x -C /out

FROM scratch
COPY --from=build /out/ /
