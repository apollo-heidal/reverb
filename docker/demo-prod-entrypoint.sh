#!/usr/bin/env bash
set -euo pipefail

export MIX_ENV="${MIX_ENV:-prod}"
export DEMO_NODE_NAME="${DEMO_NODE_NAME:-demo_prod@demo-prod}"
export REVERB_ERLANG_COOKIE="${REVERB_ERLANG_COOKIE:-reverb_demo_cookie}"

exec elixir --name "$DEMO_NODE_NAME" --cookie "$REVERB_ERLANG_COOKIE" -S mix run --no-halt
