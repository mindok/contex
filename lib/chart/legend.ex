defprotocol Contex.Legend do
  @moduledoc """
  Protocal for generating a legend.

  Implemented by specific scale modules
  """
  def to_svg(scale)
  def height(scale)
end

defimpl Contex.Legend, for: Contex.CategoryColourScale do
  import Contex.SVG

  alias Contex.CategoryColourScale

  @item_spacing 21
  @item_height 18
  def to_svg(scale) do
    values = scale.values

    legend_items =
      Enum.with_index(values)
      |> Enum.map(fn {val, index} ->
        fill = CategoryColourScale.colour_for_value(scale, val)
        y = index * @item_spacing

        [
          rect({0, 18}, {y, y + @item_height}, "", fill: fill),
          text(23, y + @item_height / 2, val, text_anchor: "start", dominant_baseline: "central")
        ]
      end)

    [~s|<g class="exc-legend">|, legend_items, "</g>"]
  end

  def height(scale) do
    value_count = length(scale.values)

    (value_count * @item_spacing) + @item_height
  end
end
