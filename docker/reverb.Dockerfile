FROM hexpm/elixir:1.18.4-erlang-27.3-debian-bookworm-20250428-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash ca-certificates git openssh-client postgresql-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/reverb

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get

COPY lib lib
COPY priv priv
COPY docker docker
COPY scripts scripts
COPY examples examples
COPY README.md README.md

RUN chmod +x scripts/demo_agent.sh docker/reverb-entrypoint.sh docker/demo-prod-entrypoint.sh

ENV MIX_ENV=prod

RUN mix compile

ENTRYPOINT ["/opt/reverb/docker/reverb-entrypoint.sh"]
