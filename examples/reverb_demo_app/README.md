# Reverb Demo App

`reverb_demo_app` is the throwaway target used to prove Reverb end to end.

It emits trivial hardcoded feature requests and exposes a tiny module with
placeholder functions that are safe for an autonomous coordinator to modify.

## Backlog

- `demo-double`
- `demo-reverse-words`
- `demo-sum-even`

Each emitted item includes:

- `subject`
- `feature_id`
- `validation_commands`
- `expected_files`

## Running Standalone

```bash
cd examples/reverb_demo_app
mix deps.get
elixir --name demo_prod@127.0.0.1 --cookie reverb_demo_cookie -S mix run --no-halt
```

For the full multi-container setup, use
`docker-compose.demo.yml`.
