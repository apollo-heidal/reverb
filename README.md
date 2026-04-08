# Reverb

Reverb is a generic Elixir library and standalone coordinator for BEAM
applications that need a safe `prod -> analyze -> develop in sandbox -> validate
-> promote` loop.

It is designed to sit between two loops:

1. A production BEAM app emits structured runtime signals over PubSub.
2. A coordinator running in a secure development sandbox receives those
   signals, turns them into durable tasks, executes isolated agent-driven
   remediation attempts, validates the result in a sandbox copy of the target
   app, and optionally promotes the change through a controlled git/PR flow.

This repo contains both halves:

- `mode: :emitter` for host applications
- `mode: :receiver` for the standalone coordinator

## Current Architecture

The current implementation includes:

- Emitter-side message broadcasting via `Reverb.emit/3`
- Receiver-side BEAM node guard and PubSub listener
- Durable task store plus raw message audit store
- Expanded task metadata for steering, leasing, validation, and promotion state
- Durable run records for execution attempts
- Subject claims to prevent duplicate concurrent work
- Scheduler-backed `Reverb.Agent.Loop` with worker slots
- Workspace pool and path-safety checks
- Coordinator-owned git boundary with protected branch rules
- CLI adapter boundary for coding agents
- Validation command runner
- Runtime status/events projection for steering surfaces

## What Is Not Built Yet

The architecture is in place, but these pieces are still intentionally thin:

- Localhost steering web UI and JSON API
- Rich merge/reconciliation policy beyond branch-local commits
- Full remote promotion workflows beyond the initial `gh`-backed path
- Per-target-app deployment/reload adapters
- Productionized release packaging

## Host App Usage

Add Reverb to a BEAM app and configure emitter mode:

```elixir
config :reverb,
  mode: :emitter,
  topic_hash: "my-app-prod",
  pubsub_name: MyApp.PubSub

config :reverb, Reverb.Emitter,
  logger_handler: true,
  levels: [:error, :warning]
```

Emit messages directly:

```elixir
Reverb.emit(:error, "Payment processing failed", source: "MyApp.Payments.charge/2")
Reverb.emit(:manual, "Investigate the deployment health check")
```

## Coordinator Usage

Configure receiver mode in the standalone coordinator:

```elixir
config :reverb,
  mode: :receiver,
  topic_hash: "my-app-prod",
  pubsub_name: MyApp.PubSub

config :reverb, Reverb.Receiver,
  prod_node: :"my_app@prod-host",
  allowed_nodes: [:"my_app@prod-host"]

config :reverb, Reverb.Workspaces,
  repo_root: "/path/to/isolated/app/clone",
  root: "/tmp/reverb/workspaces"

config :reverb, Reverb.Agent,
  enabled: true,
  max_agents: 1,
  agent_command: "hermes",
  agent_args: ["prompt", "--input", "-"],
  agent_adapter: :hermes
```

Optional validation:

```elixir
config :reverb, Reverb.Validation,
  commands: [
    "mix compile",
    "mix test"
  ]
```

Optional remote promotion:

```elixir
config :reverb, Reverb.Git,
  remote_enabled: true,
  push_enabled: true,
  remote_backend: :gh,
  protected_branches: ["main", "master", "prod"]
```

## Public APIs

- `Reverb.emit/3`
- `Reverb.status/0`
- `Reverb.pause/0`
- `Reverb.resume/0`
- `Reverb.tasks/1`
- `Reverb.get_task/1`
- `Reverb.runs/1`
- `Reverb.get_run/1`
- `Reverb.create_manual_task/1`
- `Reverb.retry_task/1`
- `Reverb.cancel_task/1`
- `Reverb.reprioritize_task/2`
- `Reverb.update_task_notes/2`
- `Reverb.agents_status/0`

## Development

The repo currently depends on Postgres for task and run persistence.

## Demo Loop

This repo now ships a disposable end-to-end demo:

- throwaway emitter app: `examples/reverb_demo_app`
- compose stack: `docker-compose.demo.yml`
- deterministic demo agent: `scripts/demo_agent.sh`

The default demo stack uses the deterministic demo agent so the full loop can be
verified without relying on a live model provider. To switch to Hermes, override
`REVERB_AGENT_ADAPTER`, `REVERB_AGENT_COMMAND`, and `REVERB_AGENT_ARGS` in the
compose environment.

## Installation Scaffold

To generate starter files in another Elixir project, run:

```bash
mix reverb.install --pubsub MyApp.PubSub --topic-hash my-app-prod
```

This currently generates additive files instead of editing `mix.exs` or existing
config automatically. It is intended as a safe first installation path and a
foundation for future Igniter integration.

Test status for the current refactor:

- `mix test` passes
- 50 tests, 0 failures

In this workspace, tests were run through Nix:

```bash
nix shell nixpkgs#elixir nixpkgs#erlang -c mix deps.get
nix shell nixpkgs#elixir nixpkgs#erlang -c mix test
```
