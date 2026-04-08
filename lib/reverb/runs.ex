defmodule Reverb.Runs do
  @moduledoc """
  Context for run attempts.
  """

  import Ecto.Query, warn: false

  alias Reverb.Repo
  alias Reverb.Runs.Run

  def status_values, do: Run.status_values()

  def create_run(attrs) when is_map(attrs) do
    %Run{}
    |> Run.changeset(normalize_attrs(attrs))
    |> Repo.insert()
  end

  def update_run(%Run{} = run, attrs) when is_map(attrs) do
    run
    |> Run.changeset(normalize_attrs(attrs))
    |> Repo.update()
  end

  def get_run(id), do: Repo.get(Run, id)
  def get_run!(id), do: Repo.get!(Run, id)

  def list_recent(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    task_id = Keyword.get(opts, :task_id)
    status = Keyword.get(opts, :status)

    query =
      Run
      |> order_by([r], desc: r.inserted_at)
      |> limit(^limit)

    query =
      if is_binary(task_id) do
        from(r in query, where: r.task_id == ^task_id)
      else
        query
      end

    query =
      if status in Run.status_values() do
        from(r in query, where: r.status == ^status)
      else
        query
      end

    Repo.all(query)
  end

  def mark_running(%Run{} = run, attrs \\ %{}) do
    update_run(run, Map.merge(%{status: :running, started_at: DateTime.utc_now()}, attrs))
  end

  def mark_validating(%Run{} = run, attrs \\ %{}) do
    update_run(run, Map.merge(%{status: :validating}, attrs))
  end

  def mark_finished(%Run{} = run, status, attrs \\ %{})
      when status in [:succeeded, :failed, :cancelled] do
    update_run(run, Map.merge(%{status: status, finished_at: DateTime.utc_now()}, attrs))
  end

  defp normalize_attrs(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      entry -> entry
    end)
  end
end
