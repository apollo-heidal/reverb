defmodule ReverbDemoApp.SimpleFeatures.DoubleTest do
  use ExUnit.Case, async: true

  alias ReverbDemoApp.SimpleFeatures

  test "double/1 multiplies by two" do
    assert SimpleFeatures.double(4) == 8
    assert SimpleFeatures.double(-3) == -6
  end
end
