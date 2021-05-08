defmodule Contex.PieChart do
  @moduledoc """
  Generates a simple pie chart from an array of numbers and headers in `Contex.Dataset`.

  Usage:

  ```
    Contex.Dataset.new([30, 23, 40], ["Category #1", "Category #2", "Category #3"])
    |> Contex.PieChart.new()
    |> Contex.PieChart.draw() # Emits svg pie chart
  ```

  The colours are using default from `Contex.CategoryColourScale.new/1` by headers in Dataset.

  The size defaults to 300 pixels high and 420 wide (chart 300 + legend 100 with margin 20). You can override by updating
  `:height`, `:width`, `:legend_width` and `:legend_margin` directly in the `PieChart` struct before call `draw/1`.
  The height and width of pie chart is always same, therefor set only height is enough.
  """
  alias __MODULE__
  alias Contex.Dataset

  defstruct [
    :dataset,
    :scaled_values,
    :fill_colours,
    height: 300,
    legend_width: 100,
    legend_margin: 20
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Create a new PieChart struct from Dataset.
  """
  def new(%Dataset{data: data, headers: headers} = dataset)
      when is_list(data) and is_list(headers) do
    %PieChart{
      dataset: dataset,
      scaled_values: scale_values(data),
      fill_colours: Contex.CategoryColourScale.new(headers)
    }
  end

  @doc """
  Renders the PieChart to svg, including the svg wrapper, as a string or improper string list that
  is marked safe.
  """
  def draw(
        %PieChart{height: height, legend_width: legend_width, legend_margin: legend_margin} =
          chart
      ) do
    width = height + legend_width + legend_margin

    output = ~s"""
      <svg height="#{height}" width="#{width}" viewBox="0 0 #{width} #{height}" preserveAspectRatio="none" role="img">
        #{generate_slices(chart)}
        #{generate_legend(chart)}
     </svg>
    """

    {:safe, [output]}
  end

  defp generate_slices(%PieChart{
         dataset: dataset,
         scaled_values: scaled_values,
         height: height,
         fill_colours: fill_colours
       }) do
    r = height / 2
    stroke_circumference = 2 * :math.pi() * r / 2

    scaled_values
    |> Enum.zip(dataset.headers)
    |> Enum.map_reduce({0, 0}, fn {value, category}, {idx, offset} ->
      text_rotation = rotate_for(value, offset)

      {
        ~s"""
          <circle r="#{r / 2}" cx="#{r}" cy="#{r}" fill="transparent"
            stroke="##{Contex.CategoryColourScale.colour_for_value(fill_colours, category)}"
            stroke-width="#{r}"
            stroke-dasharray="#{slice_value(value, stroke_circumference)} #{stroke_circumference}"
            stroke-dashoffset="-#{slice_value(offset, stroke_circumference)}">
          </circle>
          <text x="#{negate_if_flipped(r, text_rotation)}"
                y="#{negate_if_flipped(r, text_rotation)}"
            text-anchor="middle"
            fill="white"
            stroke-width="1"
            transform="rotate(#{text_rotation},#{r},#{r})
                       translate(#{r / 2}, #{negate_if_flipped(5, text_rotation)})
                       #{if need_flip?(text_rotation), do: "scale(-1,-1)"}"
          >
            #{Float.round(value, 2)}%
          </text>
        """,
        {idx + 1, offset + value}
      }
    end)
    |> elem(0)
    |> Enum.join()
  end

  defp generate_legend(chart) do
    """
      <g transform="translate(#{chart.height + chart.legend_margin}, #{chart.legend_margin})">
        #{Contex.Legend.to_svg(chart.fill_colours)}
      </g>
    """
  end

  defp slice_value(value, stroke_circumference) do
    value * stroke_circumference / 100
  end

  defp rotate_for(n, offset) do
    n / 2 * 3.6 + offset * 3.6
  end

  defp need_flip?(rotation) do
    90 < rotation and rotation < 270
  end

  defp negate_if_flipped(number, rotation) do
    if need_flip?(rotation),
      do: -number,
      else: number
  end

  defp scale_values(values) do
    values
    |> Enum.map_reduce(Enum.sum(values), &{&1 / &2 * 100, &2})
    |> elem(0)
  end
end
