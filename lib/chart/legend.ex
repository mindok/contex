defprotocol Contex.Legend do
  @moduledoc """
  Protocal for generating a legend.

  Implemented by specific scale modules
  """
  def to_svg(scale, invert \\ false)
end

defimpl Contex.Legend, for: Contex.CategoryColourScale do
  import Contex.SVG

  alias Contex.CategoryColourScale

  def to_svg(scale, invert \\ false) do
    values =
      case invert do
        true -> Enum.reverse(scale.values)
        _ -> scale.values
      end

    legend_items =
      Enum.with_index(values)
      |> Enum.map(fn {val, index} ->
        fill = CategoryColourScale.colour_for_value(scale, val)
        y = index * 21

        [
          rect({0, 18}, {y, y + 18}, "", fill: fill),
          text(23, y + 9, val, text_anchor: "start", dominant_baseline: "central")
        ]
      end)

    [~s|<g class="exc-legend">|, legend_items, "</g>"]
  end
end
