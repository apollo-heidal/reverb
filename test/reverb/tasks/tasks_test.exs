defmodule Reverb.Tasks.TasksTest do
  use Reverb.DataCase, async: false

  alias Reverb.Tasks

  defp create_task(attrs \\ %{}) do
    base = %{body: "test task #{System.unique_integer([:positive])}"}
    {:ok, task} = Tasks.create_task(Map.merge(base, attrs))
    task
  end

  describe "create_task/1" do
    test "creates a task with valid attrs" do
      assert {:ok, task} = Tasks.create_task(%{body: "Fix the bug"})
      assert task.body == "Fix the bug"
      assert task.status == :new
      assert task.severity == :medium
      assert task.error_count == 1
    end

    test "fails without body" do
      assert {:error, changeset} = Tasks.create_task(%{})
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "upsert_by_fingerprint/2" do
    test "creates new task when fingerprint is new" do
      assert {:ok, task} = Tasks.upsert_by_fingerprint("fp-new", %{body: "new error"})
      assert task.fingerprint == "fp-new"
      assert task.error_count == 1
    end

    test "increments error_count when fingerprint exists" do
      {:ok, task1} = Tasks.upsert_by_fingerprint("fp-dup", %{body: "dup error"})
      {:ok, task2} = Tasks.upsert_by_fingerprint("fp-dup", %{body: "dup error again"})

      assert task2.id == task1.id
      assert task2.error_count == 2
    end

    test "does not increment for :done tasks" do
      {:ok, task} = Tasks.upsert_by_fingerprint("fp-done", %{body: "old error"})
      Tasks.update_status(task.id, :done)

      {:ok, new_task} = Tasks.upsert_by_fingerprint("fp-done", %{body: "same error"})
      assert new_task.id != task.id
      assert new_task.error_count == 1
    end
  end

  describe "list_by_status/2" do
    test "returns tasks with given status" do
      task = create_task()
      Tasks.update_status(task.id, :todo)

      todos = Tasks.list_by_status(:todo)
      assert Enum.any?(todos, fn t -> t.id == task.id end)
    end

    test "respects limit" do
      for _ <- 1..5, do: create_task()
      assert length(Tasks.list_by_status(:new, limit: 2)) <= 2
    end
  end

  describe "update_status/2" do
    test "updates status" do
      task = create_task()
      assert {:ok, updated} = Tasks.update_status(task.id, :worked_on)
      assert updated.status == :worked_on
    end

    test "returns error for non-existent task" do
      assert {:error, :not_found} = Tasks.update_status(Ecto.UUID.generate(), :done)
    end
  end

  describe "get_task/1" do
    test "returns task by id" do
      task = create_task()
      assert Tasks.get_task(task.id).id == task.id
    end

    test "returns nil for non-existent id" do
      assert Tasks.get_task(Ecto.UUID.generate()) == nil
    end
  end
end
