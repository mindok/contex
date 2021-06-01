defmodule Contex.SimplePie do
  @moduledoc """
  Generates a simple pie chart from an array of tuples like `{"Cat", 10.0}`.

  Usage:

  ```
    SimplePie.new([{"Cat", 10.0}, {"Dog", 20.0}, {"Hamster", 5.0}])
    |> QuickPie.colours(["aa0000", "00aa00", "0000aa"]) # Optional - only if you don't like the defaults
    |> QuickPipe.draw() # Emits svg pie chart
  ```

  The colours are using default from `Contex.CategoryColourScale.new/1` by names in tuples.

  The size defaults to 50 pixels high and wide. You can override by updating
  `:height` directly in the `SimplePie` struct before call `draw/1`.
  The height and width of pie chart is always same, therefor set only height is enough.
  """
  alias __MODULE__
  alias Contex.CategoryColourScale

  defstruct [
    :data,
    :scaled_values,
    :fill_colours,
    height: 50
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Create a new SimplePie struct from list of tuples.
  """
  @spec new([{String.t(), number()}]) :: t()
  def new(data)
      when is_list(data) do
    %SimplePie{
      data: data,
      scaled_values: data |> Enum.map(&elem(&1, 1)) |> scale_values(),
      fill_colours: data |> Enum.map(&elem(&1, 0)) |> CategoryColourScale.new()
    }
  end

  @doc """
  Update the colour palette used for the slices.
  """
  @spec colours(t(), CategoryColourScale.colour_palette()) :: t()
  def colours(%SimplePie{fill_colours: fill_colours} = pie, colours) do
    custom_fill_colours = CategoryColourScale.set_palette(fill_colours, colours)
    %SimplePie{pie | fill_colours: custom_fill_colours}
  end

  @doc """
  Renders the SimplePie to svg, including the svg wrapper, as a string or improper string list that
  is marked safe.
  """
  @spec draw(t()) :: {:safe, [String.t()]}
  def draw(%SimplePie{height: height} = chart) do
    output = ~s"""
      <svg height="#{height}" width="#{height}" viewBox="0 0 #{height} #{height}" preserveAspectRatio="none" role="img">
        #{generate_slices(chart)}
     </svg>
    """

    {:safe, [output]}
  end

  defp generate_slices(%SimplePie{
         data: data,
         scaled_values: scaled_values,
         height: height,
         fill_colours: fill_colours
       }) do
    r = height / 2
    stroke_circumference = 2 * :math.pi() * r / 2
    categories = data |> Enum.map(&elem(&1, 0))

    scaled_values
    |> Enum.zip(categories)
    |> Enum.map_reduce({0, 0}, fn {value, category}, {idx, offset} ->
      {
        ~s"""
          <circle r="#{r / 2}" cx="#{r}" cy="#{r}" fill="transparent"
            stroke="##{Contex.CategoryColourScale.colour_for_value(fill_colours, category)}"
            stroke-width="#{r}"
            stroke-dasharray="#{slice_value(value, stroke_circumference)} #{stroke_circumference}"
            stroke-dashoffset="-#{slice_value(offset, stroke_circumference)}">
          </circle>
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

  defp scale_values(values) do
    values
    |> Enum.map_reduce(Enum.sum(values), &{&1 / &2 * 100, &2})
    |> elem(0)
  end
end
