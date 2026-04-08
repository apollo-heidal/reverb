defmodule Reverb.ClaimsTest do
  use ExUnit.Case, async: false

  alias Reverb.Claims

  setup do
    if is_nil(Process.whereis(Claims)) do
      start_supervised!(Claims)
    end

    :ok
  end

  test "claims and releases a subject" do
    subject = "payments.checkout.#{System.unique_integer([:positive])}"

    assert :ok = Claims.claim(subject, "agent-1", 1_000)
    assert {:ok, %{owner: "agent-1"}} = Claims.lookup(subject)
    assert :ok = Claims.release(subject, "agent-1")
    assert :error = Claims.lookup(subject)
  end

  test "prevents duplicate claims until expiry" do
    subject = "payments.checkout.#{System.unique_integer([:positive])}"

    assert :ok = Claims.claim(subject, "agent-1", 1_000)
    assert {:error, {:claimed, %{owner: "agent-1"}}} = Claims.claim(subject, "agent-2", 1_000)
  end
end
