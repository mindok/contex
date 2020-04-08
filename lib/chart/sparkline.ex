defmodule Contex.Sparkline do
  @moduledoc """
  Generates a simple sparkline from an array of numbers.

  Note that this does not follow the pattern for other types of plot. It is not designed
  to be embedded within a `Contex.Plot` and, because it only relies on a single list
  of numbers, does not use data wrapped in a `Contex.Dataset`.

  Usage is exceptionally simple:

  ```
    data = [0, 5, 10, 15, 12, 12, 15, 14, 20, 14, 10, 15, 15]
    Sparkline.new(data) |> Sparkline.draw() # Emits svg sparkline
  ```

  The colour defaults to a green line with a faded green fill, but can be overridden
  with `colours/3`. Unlike other colours in Contex, these colours are how you would
  specify them in CSS - e.g.
  ```
    Sparkline.new(data)
    |> Sparkline.colours("#fad48e", "#ff9838")
    |> Sparkline.draw()
  ```

  The size defaults to 20 pixels high and 100 wide. You can override by updating
  `:height` and `:width` directly in the `Sparkline` struct before call `draw/1`.
  """
  alias __MODULE__
  alias Contex.{ContinuousLinearScale, Scale}

  defstruct [
    :data,
    :extents,
    :length,
    :spot_radius,
    :spot_colour,
    :line_width,
    :line_colour,
    :fill_colour,
    :y_transform,
    :height,
    :width
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Create a new sparkline struct from some data.
  """
  @spec new([number()]) :: Contex.Sparkline.t()
  def new(data) when is_list(data) do
    %Sparkline{data: data, extents: ContinuousLinearScale.extents(data), length: length(data)}
    |> set_default_style
  end

  @doc """
  Override line and fill colours for the sparkline.

  Note that colours should be specified as you would in CSS - they are passed through
  directly into the SVG. For example:

  ```
    Sparkline.new(data)
    |> Sparkline.colours("#fad48e", "#ff9838")
    |> Sparkline.draw()
  ```
  """
  @spec colours(Contex.Sparkline.t(), String.t(), String.t()) :: Contex.Sparkline.t()
  def colours(%Sparkline{} = sparkline, fill, line) do
    # TODO: Really need some validation...
    %{sparkline | fill_colour: fill, line_colour: line}
  end

  defp set_default_style(%Sparkline{} = sparkline) do
    %{
      sparkline
      | spot_radius: 2,
        spot_colour: "red",
        line_width: 1,
        line_colour: "rgba(0, 200, 50, 0.7)",
        fill_colour: "rgba(0, 200, 50, 0.2)",
        height: 20,
        width: 100
    }
  end

  @doc """
  Renders the sparkline to svg, including the svg wrapper, as a string or improper string list that
  is marked safe.
  """
  def draw(%Sparkline{height: height, width: width, line_width: line_width} = sparkline) do
    vb_width = sparkline.length + 1
    vb_height = height - 2 * line_width

    scale =
      ContinuousLinearScale.new()
      |> ContinuousLinearScale.domain(sparkline.data)
      |> Scale.set_range(vb_height, 0)

    sparkline = %{sparkline | y_transform: Scale.domain_to_range_fn(scale)}

    output = ~s"""
       <svg height="#{height}" width="#{width}" viewBox="0 0 #{vb_width} #{vb_height}" preserveAspectRatio="none" role="img">
        <path d="#{get_closed_path(sparkline, vb_height)}" #{get_fill_style(sparkline)}></path>
        <path d="#{get_path(sparkline)}" #{get_line_style(sparkline)}></path>
      </svg>
    """

    {:safe, [output]}
  end

  defp get_line_style(%Sparkline{line_colour: line_colour, line_width: line_width}) do
    ~s|stroke="#{line_colour}" stroke-width="#{line_width}" fill="none" vector-effect="non-scaling-stroke"|
  end

  defp get_fill_style(%Sparkline{fill_colour: fill_colour}) do
    ~s|stroke="none" fill="#{fill_colour}"|
  end

  defp get_closed_path(%Sparkline{} = sparkline, vb_height) do
    # Same as the open path, except we drop down, run back to height,height (aka 0,0) and close it...
    open_path = get_path(sparkline)
    [open_path, "V #{vb_height} L 0 #{vb_height} Z"]
  end

  # This is the IO List approach
  defp get_path(%Sparkline{y_transform: transform_func} = sparkline) do
    last_item = Enum.count(sparkline.data) - 1

    [
      "M",
      sparkline.data
      |> Enum.map(transform_func)
      |> Enum.with_index()
      |> Enum.map(fn {value, i} ->
        case i < last_item do
          true -> "#{i} #{value} L "
          _ -> "#{i} #{value}"
        end
      end)
    ]
  end
end
