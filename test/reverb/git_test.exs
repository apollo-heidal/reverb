defmodule Reverb.GitTest do
  use ExUnit.Case, async: true

  alias Reverb.{Git, Tasks.Task}

  setup do
    original = Application.get_env(:reverb, Reverb.Git, [])

    on_exit(fn ->
      Application.put_env(:reverb, Reverb.Git, original)
    end)

    :ok
  end

  test "task_branch derives a coordinator branch" do
    task = %Task{
      id: Ecto.UUID.generate(),
      body: "Fix payment timeout",
      subject: "payments.checkout"
    }

    branch = Git.task_branch(task)
    assert String.starts_with?(branch, "reverb/task-")
    assert String.contains?(branch, "payments-checkout")
  end

  test "protected branches are rejected" do
    Application.put_env(:reverb, Reverb.Git, protected_branches: ["main", "stable"])

    assert {:error, {:protected_branch, "main"}} = Git.ensure_branch_allowed("main")
    assert :ok = Git.ensure_branch_allowed("reverb/task-123")
  end
end
