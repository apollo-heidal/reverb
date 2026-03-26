defmodule Reverb.Agent.RunnerTest do
  use ExUnit.Case, async: true

  alias Reverb.Agent.Runner

  describe "append_buffer/2" do
    test "appends data" do
      assert Runner.append_buffer("hello ", "world") == "hello world"
    end

    test "caps buffer at 50KB" do
      big_data = String.duplicate("x", 60_000)
      result = Runner.append_buffer("", big_data)
      assert byte_size(result) == 51_200
    end
  end

  describe "close_port/1" do
    test "returns :ok for nil" do
      assert Runner.close_port(nil) == :ok
    end
  end
end
