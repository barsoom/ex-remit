ERLANG_VERSION ?= `grep 'erlang_version' elixir_buildpack.config | cut -d '=' -f2`
ELIXIR_VERSION ?= `grep 'elixir_version' elixir_buildpack.config | cut -d '=' -f2`
ALPINE_VERSION ?= `grep 'alpine_version' elixir_buildpack.config | cut -d '=' -f2`
REVISION ?= `git rev-parse HEAD`
APP_NAME ?= remit

.PHONY: test-image prod-image test lint ci-test ci-lint ci plt gettext wti

test-image:
	DOCKER_BUILDKIT=1 docker build \
	  --build-arg REVISION=$(REVISION) \
	  --build-arg MIX_ENV=test \
	  --build-arg ERLANG_VERSION=$(ERLANG_VERSION) \
	  --build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) \
	  --build-arg ALPINE_VERSION=$(ALPINE_VERSION) \
	  --build-arg APP_NAME=${APP_NAME} \
	  --progress=plain \
	  --target=test \
	  -t ${APP_NAME}:test \
	  -f Dockerfile \
	  .

prod-image:
	DOCKER_BUILDKIT=1 docker build \
	  --build-arg MIX_ENV=prod \
	  --build-arg ERLANG_VERSION=$(ERLANG_VERSION) \
	  --build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) \
	  --build-arg ALPINE_VERSION=$(ALPINE_VERSION) \
	  --build-arg APP_NAME=${APP_NAME} \
	  --progress=plain \
	  --target=build \
	  -f Dockerfile \
	  .

	DOCKER_BUILDKIT=1 docker build \
	  --build-arg REVISION=$(REVISION) \
	  --build-arg MIX_ENV=prod \
	  --build-arg ERLANG_VERSION=$(ERLANG_VERSION) \
	  --build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) \
	  --build-arg ALPINE_VERSION=$(ALPINE_VERSION) \
	  --build-arg APP_NAME=${APP_NAME} \
	  --progress=plain \
	  --target=web \
	  -t ${APP_NAME}:web \
	  -f Dockerfile \
	  .

test:
	mix test

lint:
	mix lint

# This runs an isolated test suite inside Docker.
# You can also run test locally with `mix test` as usual.
ci-test: test-image
	script/ci/docker/test.sh

ci-lint: test-image
	script/ci/docker/lint.sh

# This runs some CI checks locally, to its best ability.
ci: ci-test ci-lint

gettext:
	mix gettext

import_db:
	mix logan.seed

db_console:
	./script/psql

# `wti pull` by itself changes metadata and throws away all comments, so we need
# to massage the diff to discard everything that is not a translated string.
wti:
	@status=$$(git status --porcelain); if test "x$${status}" != x; then echo Changes found in working directory, commit/discard/stash before continuing >&2; exit 1; fi
	wti pull
	git diff -U0 priv/gettext | grepdiff msgstr --output-matching=hunk > wti.patch
	git checkout priv/gettext
	git apply -p0 --unidiff-zero --allow-empty < wti.patch
	rm wti.patch

