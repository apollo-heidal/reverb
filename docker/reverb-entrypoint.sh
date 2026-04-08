#!/usr/bin/env bash
set -euo pipefail

export MIX_ENV="${MIX_ENV:-prod}"
export REVERB_DATABASE_URL="${REVERB_DATABASE_URL:-ecto://postgres:postgres@reverb-db/reverb_dev}"
export REVERB_NODE_NAME="${REVERB_NODE_NAME:-reverb@reverb}"
export REVERB_ERLANG_COOKIE="${REVERB_ERLANG_COOKIE:-reverb_demo_cookie}"
export REVERB_WORKSPACE_ROOT="${REVERB_WORKSPACE_ROOT:-/workspaces}"
export REVERB_WORKSPACE_REPO_ROOT="${REVERB_WORKSPACE_REPO_ROOT:-/sandbox/reverb_demo_app}"
export REVERB_WORKSPACE_SOURCE_REF="${REVERB_WORKSPACE_SOURCE_REF:-HEAD}"

mkdir -p "$REVERB_WORKSPACE_ROOT"

if [[ ! -d "$REVERB_WORKSPACE_REPO_ROOT/.git" ]]; then
  mkdir -p "$(dirname "$REVERB_WORKSPACE_REPO_ROOT")"
  rm -rf "$REVERB_WORKSPACE_REPO_ROOT"
  cp -R /opt/reverb/examples/reverb_demo_app "$REVERB_WORKSPACE_REPO_ROOT"
  git -C "$REVERB_WORKSPACE_REPO_ROOT" init
  git -C "$REVERB_WORKSPACE_REPO_ROOT" config user.name "Reverb Demo"
  git -C "$REVERB_WORKSPACE_REPO_ROOT" config user.email "reverb-demo@example.invalid"
  git -C "$REVERB_WORKSPACE_REPO_ROOT" add -A
  git -C "$REVERB_WORKSPACE_REPO_ROOT" commit -m "Initial demo app state"
fi

mix ecto.create
mix ecto.migrate

exec elixir --name "$REVERB_NODE_NAME" --cookie "$REVERB_ERLANG_COOKIE" -S mix run --no-halt
