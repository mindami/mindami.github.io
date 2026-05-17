ARG HUGO_VERSION=v0.161.1
FROM ghcr.io/gohugoio/hugo:${HUGO_VERSION}

ARG HUGO_VERSION

WORKDIR /src
ENV HUGO_CACHEDIR=/cache

LABEL org.opencontainers.image.title="mindami.site" \
	org.opencontainers.image.description="Containerized Hugo runtime for local and CI builds" \
	org.opencontainers.image.version="${HUGO_VERSION}"

# Hugo is the container entrypoint in the base image.
