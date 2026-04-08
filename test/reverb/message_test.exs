defmodule Reverb.MessageTest do
  use ExUnit.Case, async: true

  alias Reverb.Message

  describe "new/3" do
    test "builds a message with defaults" do
      msg = Message.new(:error, "something broke")

      assert msg.kind == :error
      assert msg.message == "something broke"
      assert msg.severity == :high
      assert msg.node == node()
      assert is_binary(msg.id)
      assert %DateTime{} = msg.timestamp
      assert msg.version == 1
    end

    test "accepts options" do
      msg =
        Message.new(:manual, "check this",
          source: "MyMod.func/2",
          severity: :low,
          metadata: %{foo: "bar"}
        )

      assert msg.kind == :manual
      assert msg.source == "MyMod.func/2"
      assert msg.severity == :low
      assert msg.metadata == %{foo: "bar"}
    end

    test "infers severity from kind" do
      assert Message.new(:error, "x").severity == :high
      assert Message.new(:warning, "x").severity == :medium
      assert Message.new(:manual, "x").severity == :medium
      assert Message.new(:telemetry, "x").severity == :medium
    end
  end

  describe "fingerprint/1" do
    test "produces a 16-char hex string" do
      msg = Message.new(:error, "something broke", source: "MyMod.func/2")
      fp = Message.fingerprint(msg)

      assert is_binary(fp)
      assert byte_size(fp) == 16
      assert fp =~ ~r/^[0-9a-f]+$/
    end

    test "same kind+source+message produces same fingerprint" do
      msg1 = Message.new(:error, "something broke", source: "MyMod.func/2")
      msg2 = Message.new(:error, "something broke", source: "MyMod.func/2")

      assert Message.fingerprint(msg1) == Message.fingerprint(msg2)
    end

    test "different messages produce different fingerprints" do
      msg1 = Message.new(:error, "error A", source: "MyMod.func/2")
      msg2 = Message.new(:error, "error B", source: "MyMod.func/2")

      assert Message.fingerprint(msg1) != Message.fingerprint(msg2)
    end

    test "normalizes dynamic parts (PIDs, timestamps)" do
      msg1 = Message.new(:error, "crash in #PID<0.1.2>", source: "MyMod")
      msg2 = Message.new(:error, "crash in #PID<0.9.9>", source: "MyMod")

      assert Message.fingerprint(msg1) == Message.fingerprint(msg2)
    end
  end
end
