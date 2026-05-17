SHELL := /bin/sh

-include .env

PROJECT_ROOT := $(CURDIR)
PUBLIC_DIR := public
PAGES_ARTIFACT := github-pages-artifact.tgz
CACHE_DIR := $(PROJECT_ROOT)/.hugo_cache

# Override these at runtime, e.g. make build SITE_URL=https://example.com/
HUGO_VERSION ?= v0.161.1
HUGO_IMAGE ?= ghcr.io/gohugoio/hugo:$(HUGO_VERSION)
SITE_URL ?= https://www.mindami.com/
PORT ?= 1313
HUGO_CACHE_DIR ?= /cache
DOCKER_COMPOSE ?= docker compose
UID ?= $(shell id -u)
GID ?= $(shell id -g)
EXTERNAL_APPS_SCRIPT ?= ./scripts/stage_external_apps.sh
EXTERNAL_APPS_CONFIG ?= ./external-apps.conf

export UID GID SITE_URL PORT HUGO_VERSION HUGO_IMAGE

UID_GID := $(shell id -u):$(shell id -g)
DOCKER_RUN := docker run --rm -u $(UID_GID) -v "$(PROJECT_ROOT):/src" -v "$(CACHE_DIR):/cache" -e HUGO_CACHEDIR="$(HUGO_CACHE_DIR)" -w /src
HUGO := $(DOCKER_RUN) $(HUGO_IMAGE)
HUGO_SERVE := $(DOCKER_RUN) -p $(PORT):$(PORT) $(HUGO_IMAGE)

.PHONY: help hugo-version validate-site-url pull prepare-cache external-apps external-apps-host build pages artifact serve serve-pages compose-build compose-pages compose-serve compose-down clean

help:
	@echo "Containerized Hugo workflow"
	@echo "  make pull         Pull Hugo container image"
	@echo "  make build        Production build into ./$(PUBLIC_DIR)"
	@echo "  make pages        GitHub Pages-like build (.nojekyll + minified output)"
	@echo "  make artifact     Tarball artifact from ./$(PUBLIC_DIR)"
	@echo "  make serve        Local server at http://localhost:$(PORT)"
	@echo "  make serve-pages  Preview with GitHub Pages base URL settings"
	@echo "  make compose-build Build with docker compose"
	@echo "  make compose-pages Build + .nojekyll with docker compose"
	@echo "  make compose-serve Serve locally with docker compose"
	@echo "  make compose-down  Stop compose services"
	@echo "  make external-apps Stage external app artifacts (Docker Node.js build)"
	@echo "  make external-apps-host Stage external app artifacts (host build engine)"
	@echo "  make hugo-version  Show pinned Hugo version"
	@echo "  Upgrade Hugo: change HUGO_VERSION in .env"
	@echo "  Site URL source: SITE_URL in .env"
	@echo "  make clean        Remove generated site output"

hugo-version:
	@echo "HUGO_VERSION=$(HUGO_VERSION)"
	@echo "HUGO_IMAGE=$(HUGO_IMAGE)"

validate-site-url:
	@test -n "$(SITE_URL)" || (echo "SITE_URL is not set. Define SITE_URL in .env"; exit 1)

pull:
	docker pull $(HUGO_IMAGE)

prepare-cache:
	mkdir -p "$(CACHE_DIR)"

external-apps:
	bash "$(EXTERNAL_APPS_SCRIPT)" --config "$(EXTERNAL_APPS_CONFIG)" --engine docker

external-apps-host:
	bash "$(EXTERNAL_APPS_SCRIPT)" --config "$(EXTERNAL_APPS_CONFIG)" --engine host

build: validate-site-url prepare-cache external-apps
	$(HUGO) --cacheDir "$(HUGO_CACHE_DIR)" --gc --minify --baseURL "$(SITE_URL)"

pages: build
	touch $(PUBLIC_DIR)/.nojekyll

artifact: pages
	tar -czf $(PAGES_ARTIFACT) -C $(PUBLIC_DIR) .
	@echo "Created $(PAGES_ARTIFACT)"

serve: prepare-cache
	$(HUGO_SERVE) server --cacheDir "$(HUGO_CACHE_DIR)" --bind 0.0.0.0 --baseURL "http://localhost:$(PORT)/" --appendPort=false --port $(PORT)

serve-pages: validate-site-url prepare-cache
	$(HUGO_SERVE) server --cacheDir "$(HUGO_CACHE_DIR)" --bind 0.0.0.0 --baseURL "$(SITE_URL)" --appendPort=false --port $(PORT)

compose-build: validate-site-url prepare-cache external-apps
	$(DOCKER_COMPOSE) run --rm hugo-build

compose-pages: compose-build
	touch $(PUBLIC_DIR)/.nojekyll

compose-serve: prepare-cache
	$(DOCKER_COMPOSE) up hugo-serve

compose-down:
	$(DOCKER_COMPOSE) down

clean:
	rm -rf $(PUBLIC_DIR) $(PAGES_ARTIFACT)