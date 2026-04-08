defmodule ReverbDemoApp.SimpleFeatures do
  @moduledoc false

  @spec double(integer()) :: integer()
  def double(_n), do: :not_implemented

  @spec reverse_words(String.t()) :: String.t()
  def reverse_words(_value), do: :not_implemented

  @spec sum_even([integer()]) :: integer()
  def sum_even(_values), do: :not_implemented
end
