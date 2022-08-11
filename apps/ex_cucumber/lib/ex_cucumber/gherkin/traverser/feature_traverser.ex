defmodule ExCucumber.Gherkin.Traverser.Feature do
  @moduledoc false

  alias ExCucumber.Gherkin.Traverser.Ctx
  alias ExCucumber.Gherkin.Traverser, as: MainTraverser

  alias ExGherkin.AstNdjson.Background

  require Logger

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
        updated_ctx = MainTraverser.run(background, ctx, parse_tree)

        child
        |> case do
          %{scenario: scenario} ->
            MainTraverser.run(scenario, uodated_ctx, parse_tree)

          %{rule: rule} ->
            MainTraverser.run(rule, uodated_ctx, parse_tree)
        end
      end)

    callback_on_success(result)

    result
  end

  defp callback_on_success(result) do
    case Module.get_attribute(result.module, :on_feature_success) do
      nil ->
        :ok

      on_feature_success when is_function(on_feature_success, 1) ->
        callback(on_feature_success, result)

      _invalid ->
        raise ArgumentError,
          message: "invalid `@on_feature_success` module attribute in: " <> inspect(__MODULE__)
    end
  end

  defp callback(on_feature_success, result) do
    try do
      on_feature_success.(result)
    rescue
      e ->
        Logger.error(
          "Error [#{inspect(e)}] raised when tring to callback the on_feature_success function in: " <>
            inspect(__MODULE__)
        )

        reraise e, __STACKTRACE__
    catch
      :exit ->
        Logger.error(
          "Error process was `exited` when tring to callback the on_feature_success function in: " <>
            inspect(__MODULE__)
        )

      thrown ->
        Logger.error(
          "Error [#{inspect(thrown)}] was thrown when tring to callback the on_feature_success function in: " <>
            inspect(__MODULE__)
        )
    end
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
