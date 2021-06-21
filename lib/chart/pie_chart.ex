defmodule Contex.PieChart do
  alias __MODULE__
  alias Contex.Dataset

  defstruct [
    :dataset,
    :options
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Create a new PieChart struct from Dataset.
  """
  def new(%Dataset{data: data} = dataset, options \\ []) when is_list(options) do
    %PieChart{
      dataset: dataset,
      options: options
      #scaled_values: scale_values(data),
      #fill_colours: Contex.CategoryColourScale.new(headers)
    }
  end

  @doc false
  def set_size(%PieChart{} = plot, width, height) do
    plot
    |> set_option(:width, width)
    |> set_option(:height, height)
  end

  @doc false
  def get_svg_legend(%PieChart{dataset: dataset} = plot) do
    Contex.Dataset.column_names(dataset)
    |> Contex.CategoryColourScale.new()
    |> Contex.Legend.to_svg()
  end

  @doc """
  Renders the PieChart to svg, including the svg wrapper, as a string or improper string list that
  is marked safe.
  """
  def to_svg( %PieChart{} = chart) do
    [
      "<g>",
        generate_slices(chart),
      "</g>",
    ]
  end

  defp set_option(%PieChart{options: options} = plot, key, value) do
    options = Keyword.put(options, key, value)

    %{plot | options: options}
  end

  defp generate_slices(%PieChart{
         dataset: dataset,
         options: %{height: height}
         #scaled_values: scaled_values,
         #height: height,
         #fill_colours: fill_colours
       } = chart) do
    r = height / 2
    stroke_circumference = 2 * :math.pi() * r / 2

    scale_values(chart)
    |> Enum.zip(Contex.Dataset.column_names(dataset))
    |> Enum.map_reduce({0, 0}, fn {value, category}, {idx, offset} ->
      text_rotation = rotate_for(value, offset)

    fill_colours = Contex.Dataset.column_names(dataset)
    |> Contex.CategoryColourScale.new()

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

  defp scale_values(%PieChart{dataset: dataset}) do
    dataset.data
    |> Enum.map_reduce(Enum.sum(dataset.data), &{&1 / &2 * 100, &2})
    |> elem(0)
  end
end
