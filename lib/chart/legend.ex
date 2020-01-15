defprotocol Contex.Legend do
  def to_svg(scale, invert \\ false)
end

defimpl Contex.Legend, for: Contex.CategoryColourScale do
  alias Contex.CategoryColourScale

  def to_svg(scale, invert \\ false) do
    values = case invert do
      true -> Enum.reverse(scale.values)
      _ -> scale.values
    end

    legend_items
    = Enum.with_index(values)
    |> Enum.map(fn {val, index} ->
        fill = CategoryColourScale.colour_for_value(scale, val)
        y = index * 21
        [~s|<rect x="0" y="#{y}" width="18" height="18" style="fill: ##{fill};"></rect>|,
        ~s|<text x="23" y="#{y + 9}" text-anchor="start" dominant-baseline="central">#{val}</text>|]
      end)

    [~s|<g class="exc-legend">|, legend_items, "</g>"]
  end
end
