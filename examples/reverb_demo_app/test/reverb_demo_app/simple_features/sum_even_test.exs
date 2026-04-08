defmodule ReverbDemoApp.SimpleFeatures.SumEvenTest do
  use ExUnit.Case, async: true

  alias ReverbDemoApp.SimpleFeatures

  test "sum_even/1 sums only even numbers" do
    assert SimpleFeatures.sum_even([1, 2, 3, 4, 5, 6]) == 12
    assert SimpleFeatures.sum_even([1, 3, 5]) == 0
  end
end
