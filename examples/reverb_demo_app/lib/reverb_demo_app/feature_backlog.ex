defmodule ReverbDemoApp.FeatureBacklog do
  @moduledoc """
  Hardcoded trivial backlog for deterministic Reverb end-to-end verification.
  """

  def items do
    [
      %{
        id: "demo-double",
        subject: "simple_features.double/1",
        source_kind: "demo_feature",
        priority: 10,
        body: "Implement ReverbDemoApp.SimpleFeatures.double/1 so it returns n * 2.",
        validation_commands: ["mix test test/reverb_demo_app/simple_features/double_test.exs"],
        expected_files: [
          "lib/reverb_demo_app/simple_features.ex",
          "test/reverb_demo_app/simple_features/double_test.exs"
        ],
        difficulty: "trivial"
      },
      %{
        id: "demo-reverse-words",
        subject: "simple_features.reverse_words/1",
        source_kind: "demo_feature",
        priority: 20,
        body:
          "Implement ReverbDemoApp.SimpleFeatures.reverse_words/1 so it reverses word order in a string.",
        validation_commands: [
          "mix test test/reverb_demo_app/simple_features/reverse_words_test.exs"
        ],
        expected_files: [
          "lib/reverb_demo_app/simple_features.ex",
          "test/reverb_demo_app/simple_features/reverse_words_test.exs"
        ],
        difficulty: "trivial"
      },
      %{
        id: "demo-sum-even",
        subject: "simple_features.sum_even/1",
        source_kind: "demo_feature",
        priority: 30,
        body:
          "Implement ReverbDemoApp.SimpleFeatures.sum_even/1 so it sums only even integers from a list.",
        validation_commands: ["mix test test/reverb_demo_app/simple_features/sum_even_test.exs"],
        expected_files: [
          "lib/reverb_demo_app/simple_features.ex",
          "test/reverb_demo_app/simple_features/sum_even_test.exs"
        ],
        difficulty: "trivial"
      }
    ]
  end
end
