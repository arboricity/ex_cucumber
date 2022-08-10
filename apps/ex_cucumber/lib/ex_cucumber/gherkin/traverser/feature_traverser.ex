defmodule ExCucumber.Gherkin.Traverser.Feature do
  @moduledoc false

  alias ExCucumber.Gherkin.Traverser.Ctx
  alias ExCucumber.Gherkin.Traverser, as: MainTraverser

  alias ExGherkin.AstNdjson.Background

  def run(%ExGherkin.AstNdjson.Feature{children: nil}, acc, _), do: acc

  def run(%ExGherkin.AstNdjson.Feature{} = f, acc, parse_tree) do
    {background, children} = background(f.children)

    merged_ctx =
      Ctx.extra(
        acc,
        Map.merge(feature_meta(f), %{state: %{}, step_history: [], context_history: []})
      )

    result =
      children
      |> Enum.reduce(merged_ctx, fn child, ctx ->
        uodated_ctx = MainTraverser.run(background, ctx, parse_tree)

        child
        |> case do
          %{scenario: scenario} ->
            MainTraverser.run(scenario, uodated_ctx, parse_tree)

          %{rule: rule} ->
            MainTraverser.run(rule, uodated_ctx, parse_tree)
        end
      end)

    if Module.has_attribute?(result.module, :on_feature_success) do
      on_feature_success = Module.get_attribute(result.module, :on_feature_success)
      if is_function(on_feature_success, 1), do: on_feature_success.(result)
    end

    result
  end

  defp background([]), do: {nil, []}
  defp background([%{background: b = %Background{}}]), do: {b, []}
  defp background([%{background: b = %Background{}} | tl]), do: {b, tl}
  defp background(ls), do: {nil, ls}

  defp feature_meta(feature) do
    %{
      feature: %{
        language: feature.language,
        title: feature.name,
        location: Map.from_struct(feature.location),
        keyword: feature.keyword,
        tags: feature.tags
      }
    }
  end
end
