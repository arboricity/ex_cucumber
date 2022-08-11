defmodule ExCucumber.Gherkin.Traverser.Scenario do
  @moduledoc false

  alias ExCucumber.Gherkin.Traverser.Ctx
  alias ExCucumber.Gherkin.Traverser, as: MainTraverser
  alias ExGherkin.AstNdjson.Examples

  require Logger

  def run(%ExGherkin.AstNdjson.Scenario{} = s, acc, parse_tree) do
    result =
      s
      |> relevant_examples
      |> Enum.reduce(acc, fn {tags, rows}, ctx ->
        rows
        |> Enum.reduce(ctx, fn row, context ->
          steps =
            if s.steps do
              s.steps
            else
              IO.warn(
                "Empty scenario encountered: #{context.feature_file}:#{s.location.line}:#{s.location.column}"
              )

              []
            end

          steps
          |> Enum.reduce(
            Ctx.extra(context, scenario_meta(context.extra.context_history, s, tags, row)),
            fn
              %ExGherkin.AstNdjson.Step{} = step, a -> MainTraverser.run(step, a, parse_tree)
            end
          )
        end)
      end)

    callback_on_success(result)

    result
  end

  defp callback_on_success(result) do
    case Module.get_attribute(result.module, :on_scenario_success) do
      nil ->
        :ok

      on_scenario_success when is_function(on_scenario_success, 1) ->
        callback(on_scenario_success, result)

      _invalid ->
        raise ArgumentError,
          message: "invalid `@on_scenario_success` module attribute in: " <> inspect(__MODULE__)
    end
  end

  defp callback(on_scenario_success, result) do
    try do
      on_scenario_success.(result)
    rescue
      e ->
        Logger.error(
          "Error [#{inspect(e)}] raised when tring to callback the on_scenario_success function in: " <>
            inspect(__MODULE__)
        )

        reraise e, __STACKTRACE__
    catch
      :exit ->
        Logger.error(
          "Error process was `exited` when tring to callback the on_scenario_success function in: " <>
            inspect(__MODULE__)
        )

      thrown ->
        Logger.error(
          "Error [#{inspect(thrown)}] was thrown when tring to callback the on_scenario_success function in: " <>
            inspect(__MODULE__)
        )
    end
  end

  defp example_tables(nil), do: [{nil, [%{}]}]
  defp example_tables([]), do: [{nil, [%{}]}]
  defp example_tables(examples), do: Enum.map(examples, &Examples.table_to_tagged_map/1)

  defp relevant_examples(scenario) do
    {tags, rows} = example_tables(scenario.examples) |> List.first()
    [{tags, rows}]
  end

  defp scenario_meta(context_history, scenario, example_tags, example_row)
       when is_map(example_row) do
    scenario_details =
      if scenario.parsed_sentence do
        title =
          scenario.parsed_sentence.vars
          |> Enum.reduce(scenario.parsed_sentence.template, fn
            var, template ->
              example = Map.fetch!(example_row, var)
              String.replace(template, "%", "#{example}", global: false)
          end)

        %{
          name: :scenario,
          type: scenario.keyword,
          raw: scenario.name,
          title: title,
          location: Map.from_struct(scenario.location),
          keyword: scenario.keyword,
          tags: scenario.tags
        }
      else
        %{
          name: :scenario,
          type: scenario.keyword,
          raw: scenario.name,
          title: scenario.name,
          location: Map.from_struct(scenario.location),
          keyword: scenario.keyword,
          tags: scenario.tags
        }
      end

    context_history = context_history |> Enum.reject(&(&1.name == :background))

    %{
      step_history: [],
      context_history: [scenario_details | context_history],
      scenario: scenario_details,
      examples: %{tags: example_tags, row: example_row}
    }
  end
end
