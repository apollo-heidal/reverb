defmodule Reverb.Tasks do
  @moduledoc """
  Context module for managing Reverb tasks.

  Provides CRUD operations, status queries, and fingerprint-based upsert
  for error deduplication.
  """

  import Ecto.Query, warn: false
  alias Reverb.Repo
  alias Reverb.Tasks.Task

  def status_values, do: Task.status_values()
  def severity_values, do: Task.severity_values()

  @doc "Creates a new task."
  def create_task(attrs) when is_map(attrs) do
    attrs = normalize_attrs(attrs)

    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a task or increments error_count if a task with the same fingerprint
  already exists in an active status (:new, :todo, :worked_on).
  """
  def upsert_by_fingerprint(fingerprint, attrs) when is_binary(fingerprint) do
    active_statuses = [:new, :todo, :worked_on]

    case Repo.one(
           from(t in Task,
             where: t.fingerprint == ^fingerprint and t.status in ^active_statuses,
             limit: 1
           )
         ) do
      nil ->
        attrs = attrs |> normalize_attrs() |> Map.put("fingerprint", fingerprint)
        create_task(attrs)

      existing ->
        existing
        |> Ecto.Changeset.change(%{error_count: existing.error_count + 1})
        |> Repo.update()
    end
  end

  @doc "Lists recent tasks."
  def list_recent(opts \\ []) do
    since_minutes = Keyword.get(opts, :since_minutes)
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status)

    base =
      Task
      |> order_by([t], desc: t.inserted_at)
      |> limit(^limit)

    base =
      if since_minutes && since_minutes > 0 do
        since = DateTime.add(DateTime.utc_now(), -since_minutes * 60, :second)
        from(t in base, where: t.inserted_at >= ^since)
      else
        base
      end

    base =
      if status && status in Task.status_values() do
        from(t in base, where: t.status == ^status)
      else
        base
      end

    Repo.all(base)
  end

  @doc "Lists tasks by status."
  def list_by_status(status, opts \\ []) when status in [:new, :todo, :worked_on, :done] do
    limit = Keyword.get(opts, :limit, 50)

    Task
    |> where([t], t.status == ^status)
    |> order_by([t], desc: t.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Updates the status of a task."
  def update_status(id, status) when status in [:new, :todo, :worked_on, :done] do
    case Repo.get(Task, id) do
      nil -> {:error, :not_found}
      task -> task |> Ecto.Changeset.change(%{status: status}) |> Repo.update()
    end
  end

  def update_status(_, _), do: {:error, :invalid_status}

  @doc "Gets a single task by id."
  def get_task(id) do
    Repo.get(Task, id)
  end

  @doc "Gets a single task by id, raises if not found."
  def get_task!(id) do
    Repo.get!(Task, id)
  end

  @doc "Updates a task with the given attributes."
  def update_task(%Task{} = task, attrs) when is_map(attrs) do
    task
    |> Task.changeset(normalize_attrs(attrs))
    |> Repo.update()
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {to_string(k), v}
      {k, v} -> {k, v}
    end)
    |> Map.new()
  end
end
