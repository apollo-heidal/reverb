defmodule ReverbDemoApp.SimpleFeatures.ReverseWordsTest do
  use ExUnit.Case, async: true

  alias ReverbDemoApp.SimpleFeatures

  test "reverse_words/1 reverses word order" do
    assert SimpleFeatures.reverse_words("one two three") == "three two one"
    assert SimpleFeatures.reverse_words("solo") == "solo"
  end
end
