defmodule Reverb.ValidationTest do
  use ExUnit.Case, async: true

  alias Reverb.Validation

  test "succeeds when no commands are configured" do
    assert {:ok, ""} = Validation.run("/tmp", commands: [])
  end

  test "returns combined output on failure" do
    assert {:error, %{exit_code: 7, combined_output: output}} =
             Validation.run("/tmp", commands: ["printf ok", "printf nope && exit 7"])

    assert output =~ "$ printf ok"
    assert output =~ "$ printf nope && exit 7"
  end
end
