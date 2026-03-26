defmodule Reverb.TopicTest do
  use ExUnit.Case, async: true

  alias Reverb.Topic

  describe "name/0" do
    test "returns a topic string based on config hash" do
      Application.put_env(:reverb, :topic_hash, "test-hash-123")
      name = Topic.name()

      assert String.starts_with?(name, "reverb:")
      assert byte_size(name) > 7
    end

    test "same hash produces same topic" do
      Application.put_env(:reverb, :topic_hash, "stable")
      name1 = Topic.name()
      name2 = Topic.name()

      assert name1 == name2
    end

    test "different hashes produce different topics" do
      Application.put_env(:reverb, :topic_hash, "hash-a")
      name_a = Topic.name()

      Application.put_env(:reverb, :topic_hash, "hash-b")
      name_b = Topic.name()

      assert name_a != name_b
    end
  end
end
