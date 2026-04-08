FROM hexpm/elixir:1.18.4-erlang-27.3-debian-bookworm-20250428-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash ca-certificates git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/reverb/examples/reverb_demo_app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock /opt/reverb/
COPY config /opt/reverb/config
COPY lib /opt/reverb/lib
COPY priv /opt/reverb/priv
COPY docker /opt/reverb/docker
COPY examples/reverb_demo_app /opt/reverb/examples/reverb_demo_app

RUN mix deps.get && chmod +x /opt/reverb/docker/demo-prod-entrypoint.sh

ENTRYPOINT ["/opt/reverb/docker/demo-prod-entrypoint.sh"]
