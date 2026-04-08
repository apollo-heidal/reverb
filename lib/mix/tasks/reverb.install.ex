defmodule Mix.Tasks.Reverb.Install do
  use Mix.Task

  @shortdoc "Generates starter Reverb integration files for the current project"

  @moduledoc """
  Generates starter files to connect the current Elixir project to a standalone
  Reverb coordinator.

      mix reverb.install
      mix reverb.install --pubsub MyApp.PubSub --topic-hash my-app-prod

  This task intentionally generates additive files and avoids rewriting
  existing config files aggressively.
  """

  @switches [force: :boolean, pubsub: :string, topic_hash: :string]

  @impl true
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: @switches)
    app = Mix.Project.config()[:app] |> to_string()
    module_base = Macro.camelize(app)
    pubsub = opts[:pubsub] || "#{module_base}.PubSub"
    topic_hash = opts[:topic_hash] || "#{app}-prod"
    force? = opts[:force] || false

    targets = [
      {"config/reverb.exs", config_template(pubsub, topic_hash)},
      {".env.reverb", env_template(app, topic_hash)},
      {".reverb.cookie.example", cookie_template()},
      {"docker-compose.reverb.yml", compose_template(app)},
      {"README.reverb.md", readme_template(app, pubsub, topic_hash)}
    ]

    Enum.each(targets, fn {path, contents} ->
      write_file(path, contents, force?)
    end)

    Mix.shell().info("""

    Reverb starter files generated.

    Next steps:
      1. Add `import_config "reverb.exs"` to your main config if desired.
      2. Set a shared cookie in `.env.reverb`.
      3. Boot the standalone coordinator with `docker compose -f docker-compose.reverb.yml up`.
    """)
  end

  defp write_file(path, contents, force?) do
    if File.exists?(path) and not force? do
      Mix.shell().info("skip #{path} (already exists, use --force to overwrite)")
    else
      path |> Path.dirname() |> File.mkdir_p!()
      File.write!(path, contents)
      Mix.shell().info("wrote #{path}")
    end
  end

  defp config_template(pubsub, topic_hash) do
    """
    import Config

    config :reverb,
      mode: :emitter,
      topic_hash: "#{topic_hash}",
      pubsub_name: #{pubsub}

    config :reverb, Reverb.Emitter,
      logger_handler: false,
      telemetry_events: []
    """
  end

  defp env_template(app, topic_hash) do
    """
    REVERB_TOPIC_HASH=#{topic_hash}
    REVERB_PUBSUB_NAME=#{Macro.camelize(app)}.PubSub
    REVERB_ERLANG_COOKIE=replace-me-with-a-shared-cookie
    """
  end

  defp cookie_template do
    Base.encode16(:crypto.strong_rand_bytes(24), case: :lower) <> "\n"
  end

  defp compose_template(app) do
    """
    services:
      reverb:
        image: ghcr.io/your-org/reverb:latest
        env_file:
          - .env.reverb
        environment:
          REVERB_MODE: receiver
          REVERB_PROD_NODE: #{app}@host.docker.internal
          REVERB_ALLOWED_NODES: #{app}@host.docker.internal
          REVERB_WORKSPACE_REPO_ROOT: /sandbox/#{app}
          REVERB_WORKSPACE_ROOT: /workspaces
        volumes:
          - ./tmp/reverb-workspaces:/workspaces
          - ./:/sandbox/#{app}
    """
  end

  defp readme_template(app, pubsub, topic_hash) do
    """
    # Reverb Integration

    Generated for `#{app}`.

    ## Add To Your App

    1. Add `{:reverb, path: "..."}`
    2. Import `config/reverb.exs` from your config tree.
    3. Ensure your PubSub is started: `#{pubsub}`.

    ## Shared Values

    - Topic hash: `#{topic_hash}`
    - Cookie source: `.reverb.cookie.example`
    - Coordinator env file: `.env.reverb`

    ## Safe Defaults

    - Remote push disabled
    - Coordinator expected to run separately from the app
    - Workspace writes isolated to `/workspaces`
    """
  end
end
