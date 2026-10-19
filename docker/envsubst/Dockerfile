# syntax=docker/dockerfile:1
# Image builder : envsubst (gomodules.xyz/envsubst) compilé en statique, seul dans une
# image scratch, prêt à être copié dans les images Prometheus et Alertmanager.
ARG GO_VERSION

FROM golang:${GO_VERSION}-alpine AS build
ARG ENVSUBST_VERSION
RUN CGO_ENABLED=0 go install gomodules.xyz/envsubst/cmd/envsubst@${ENVSUBST_VERSION}

FROM scratch
COPY --from=build /go/bin/envsubst /bin/envsubst
