defmodule Reverb.Agent.CLI.HermesTest do
  use ExUnit.Case, async: true

  alias Reverb.Agent.CLI

  @capture_script Path.expand("test/support/fixtures/capture_prompt.sh")

  test "runs hermes adapter with provider flags and stdin prompt" do
    assert {:ok, result} =
             CLI.run("implement the feature",
               adapter: :hermes,
               command: @capture_script,
               args: ["prompt", "--input", "-"],
               provider: "openai",
               model: "gpt-5.4"
             )

    assert result.provider == :hermes
    assert result.output =~ "ARGS:--provider openai --model gpt-5.4 prompt --input -"
    assert result.output =~ "implement the feature"
  end
end
