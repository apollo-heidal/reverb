defmodule Reverb.Agent.Rotation do
  @moduledoc """
  Configurable default rotation tasks for the agent loop.

  When the task queue is empty, the agent cycles through these activities.
  Override via config:

      config :reverb, Reverb.Agent,
        rotation_tasks: ["Custom task 1", "Custom task 2"]
  """

  @default_tasks [
    "Security audit — Review recent git changes for vulnerabilities, check for exposed secrets, OWASP top 10 issues.",
    "UI testing — Run available tests, check for visual regressions, verify responsive layout.",
    "UX review — Check user flows for friction, verify error messages are helpful, review form validations.",
    "Documentation — Keep docs/ in sync with code changes, update API docs, check for stale references.",
    "Dependency update — Check for outdated dependencies, update if safe, verify no breaking changes.",
    "Code cleanup — Remove debug statements, dead code, resolve TODOs.",
    "Test coverage — Write tests for untested modules, check coverage gaps.",
    "Performance — Check for N+1 queries, slow paths, optimize hot code paths.",
    "CI/CD — Improve build/deploy pipeline, check CI workflows."
  ]

  @doc "Returns the list of rotation tasks."
  def tasks do
    case Application.get_env(:reverb, Reverb.Agent, []) |> Keyword.get(:rotation_tasks, :default) do
      :default -> @default_tasks
      custom when is_list(custom) -> custom
    end
  end

  @doc "Returns the rotation task at the given index (wraps around)."
  def at(index) do
    tasks = tasks()
    Enum.at(tasks, rem(index, length(tasks)))
  end

  @doc "Returns the number of rotation tasks."
  def count, do: length(tasks())
end
