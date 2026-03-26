defmodule Reverb.Tasks.TaskTest do
  use Reverb.DataCase, async: true

  alias Reverb.Tasks.Task

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = Task.changeset(%Task{}, %{"body" => "Fix this bug"})
      assert changeset.valid?
    end

    test "invalid without body" do
      changeset = Task.changeset(%Task{}, %{})
      refute changeset.valid?
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates body length" do
      changeset = Task.changeset(%Task{}, %{"body" => String.duplicate("x", 16_001)})
      refute changeset.valid?
    end

    test "accepts all optional fields" do
      changeset =
        Task.changeset(%Task{}, %{
          "body" => "task",
          "category" => "error",
          "source_id" => "prod@server",
          "fingerprint" => "abc123",
          "error_count" => 5,
          "severity" => "high",
          "status" => "todo",
          "done_note" => "fixed",
          "metadata" => %{"key" => "val"}
        })

      assert changeset.valid?
    end
  end

  describe "status_values/0" do
    test "returns expected statuses" do
      assert Task.status_values() == [:new, :todo, :worked_on, :done]
    end
  end

  describe "severity_values/0" do
    test "returns expected severities" do
      assert Task.severity_values() == [:critical, :high, :medium, :low]
    end
  end
end
