ARG ERLANG_VERSION
ARG ELIXIR_VERSION
ARG ALPINE_VERSION

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} AS build

ENV MIX_HOME=/tmp/mix \
  HEX_HOME=/tmp/hex \
  DEPS_PATH=/tmp/deps \
  BUILD_PATH=/tmp/build

WORKDIR /app

RUN apk --no-cache add git npm && \
  mix local.hex --force && \
  mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}

RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Do not copy PLT files into the image if any are present
RUN mkdir priv && mkdir priv/plts
COPY priv/gettext priv/gettext
COPY priv/repo priv/repo
COPY priv/static priv/static

COPY assets assets
COPY lib lib

RUN mix compile --warnings-as-errors
RUN mix assets.setup
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/
COPY .formatter.exs .credo.exs ./
COPY rel rel
RUN mix release

FROM build AS test
RUN apk add --no-cache bash
COPY test test

FROM alpine:${ALPINE_VERSION} AS web

WORKDIR /app
RUN chown nobody /app

RUN apk --no-cache add ncurses libgcc libstdc++ curl postgresql-client

ARG APP_NAME
COPY --from=build --chown=nobody:root /app/_build/prod/rel/${APP_NAME}/ ./

USER nobody

ARG REVISION
ENV PORT=80 \
  REVISION=${REVISION}

COPY ./.iex.exs /app/
COPY Procfile /app/

CMD /app/bin/server
