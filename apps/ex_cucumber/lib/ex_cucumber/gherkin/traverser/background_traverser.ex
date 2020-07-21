defmodule ExCucumber.Gherkin.Traverser.Background do
  @moduledoc false

  alias ExCucumber.Gherkin.Traverser.Ctx
  alias ExCucumber.Gherkin.Traverser, as: MainTraverser

  alias ExGherkin.AstNdjson.{
    Background,
    Step
  }

  def run(%Background{} = b, acc, parse_tree) do
    acc = Ctx.extra(acc, background_meta(b))

    b.steps
    |> Enum.reduce(acc, fn
      %Step{} = step, a -> MainTraverser.run(step, a, parse_tree)
    end)
  end

  defp background_meta(background) do
    %{
      background: %{
        title: background.name,
        location: Map.from_struct(background.location),
        keyword: background.keyword
      }
    }
  end
end
