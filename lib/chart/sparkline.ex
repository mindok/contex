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

  You can modify various rendering properties through `style/2`. These properties
  map directly to the underlying elements (line & area), giving you great flexibility to
  style them in various ways -e.g.

  Use color values & dimensions:

  ```
    Sparkline.new(data)
    |> Sparkline.style(line_stroke: "#fad48e", area_fill: "#ff9838", height: 50, width: 300)
    |> Sparkline.draw()
  ```

  Use classes:

  ```
    Sparkline.new(data)
    |> Sparkline.style(
        line_stroke: nil,
        area_fill: nil,
        line_class: "stroke-blue-500",
        area_class: "fill-blue-50"
    )
    |> Sparkline.draw()
  ```

  Injecting extra_elements:

  ```
    extra_svg = \"""
    <defs>
      <linearGradient id="pretty-gradient" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" style="stop-color:#b794f4;stop-opacity:1" />
        <stop offset="100%" style="stop-color:#f56565;stop-opacity:1" />
      </linearGradient>
    </defs>
    \"""

    Sparkline.new(data)
    |> Sparkline.style(line_stroke: "url(#pretty-gradient)", extra_svg: extra_svg)
    |> Sparkline.draw()
  ```


  """
  alias __MODULE__
  alias Contex.{ContinuousLinearScale, Scale}

  defstruct [
    :data,
    :extents,
    :length,
    :y_transform,
    :height,
    :width,
    :extra_svg,
    :line_stroke,
    :line_class,
    :line_stroke_width,
    :line_stroke_linecap,
    :line_stroke_linejoin,
    :line_fill,
    :area_stroke,
    :area_fill,
    :area_class
  ]

  @type t() :: %__MODULE__{}

  @default_style [
    height: 20,
    width: 100,
    extra_svg: nil,
    line_stroke: "rgba(0, 200, 50, 0.7)",
    line_class: nil,
    line_stroke_width: 1,
    line_stroke_linecap: "round",
    line_stroke_linejoin: "round",
    line_fill: "none",
    area_stroke: "none",
    area_fill: "rgba(0, 200, 50, 0.2)",
    area_class: nil
  ]

  @doc """
  Create a new sparkline struct from some data.
  """
  @spec new([number()]) :: Contex.Sparkline.t()
  def new(data) when is_list(data) do
    %Sparkline{data: data, extents: ContinuousLinearScale.extents(data), length: length(data)}
    |> style()
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
  @deprecated "Use style/2 instead"
  @since "0.5.0"
  @spec colours(Contex.Sparkline.t(), String.t(), String.t()) :: Contex.Sparkline.t()
  def colours(%Sparkline{} = sparkline, area_fill, line_stroke) do
    # TODO: Really need some validation...
    style(sparkline, area_fill: area_fill, line_stroke: line_stroke)
  end

  @doc """
  Override any of the style settings for the sparkline.

  There are 3 elements in a sparkline, wrapping svg, a line and an area.
  To control how they are rendered, you can pass ony of the following
  parameters:

  * height: 20
  * width: 100
  * extra_svg: nil
  * line_stroke: "rgba(0, 200, 50, 0.7)"
  * line_class: nil
  * line_stroke_width: 1
  * line_stroke_linecap: "round"
  * line_stroke_linejoin: "round"
  * line_fill: "none"
  * area_stroke: "none"
  * area_fill: "rgba(0, 200, 50, 0.2)"
  * area_class: nil

  Example 1: Set color values & dimensions:

  ```
    Sparkline.new(data)
    |> Sparkline.style(line_stroke: "#fad48e", area_fill: "#ff9838", height: 50, width: 300)
    |> Sparkline.draw()
  ```

  Example 2: Set classes

  ```
    Sparkline.new(data)
    |> Sparkline.style(
        line_stroke: nil,
        area_fill: nil,
        line_class: "stroke-blue-500",
        area_class: "fill-blue-50"
    )
    |> Sparkline.draw()
  ```

  Example 3: Add a gradient

  ```
    extra_svg = \"""
    <defs>
      <linearGradient id="pretty-gradient" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" style="stop-color:#b794f4;stop-opacity:1" />
        <stop offset="100%" style="stop-color:#f56565;stop-opacity:1" />
      </linearGradient>
    </defs>
    \"""

    Sparkline.new(data)
    |> Sparkline.style(line_stroke: "url(#pretty-gradient)", extra_svg: extra_svg)
    |> Sparkline.draw()
  ```
  """
  @spec style(Contex.Sparkline.t(),
          height: :integer,
          width: :integer,
          extra_svg: String.t() | nil,
          line_stroke: :integer,
          line_class: String.t() | nil,
          line_stroke_width: :integer,
          line_stroke_linecap: String.t() | nil,
          line_stroke_linejoin: String.t() | nil,
          line_fill: String.t() | nil,
          area_stroke: String.t() | nil,
          area_fill: String.t() | nil,
          area_class: String.t() | nil
        ) :: Contex.Sparkline.t()
  def style(%Sparkline{} = sparkline, options \\ []) do
    props =
      @default_style
      |> Keyword.merge(options)
      |> Enum.into(%{})

    Map.merge(sparkline, props)
  end

  @doc """
  Renders the sparkline to svg, including the svg wrapper, as a string or improper string list that
  is marked safe.
  """
  def draw(%Sparkline{} = chart) do
    vb_width = chart.length + 1
    vb_height = chart.height - 2 * chart.line_stroke_width

    scale =
      ContinuousLinearScale.new()
      |> ContinuousLinearScale.domain(chart.data)
      |> Scale.set_range(0, vb_height)

    chart = %{chart | y_transform: Scale.domain_to_range_fn(scale)}

    output = ~s"""
       <svg height="#{chart.height}" width="#{chart.width}" viewBox="0 0 #{vb_width} #{vb_height}" preserveAspectRatio="none" role="img">
        #{chart.extra_svg}
        <g transform="translate(0,#{vb_height})">
          <g transform="scale(1,-1)">
            <path d="#{get_area_path(chart)}" #{get_area_style(chart)}></path>
            <path d="#{get_line_path(chart)}" #{get_line_style(chart)}></path>
          </g>
        </g>
      </svg>
    """

    {:safe, [output]}
  end

  defp get_line_style(%Sparkline{
         line_stroke: line_stroke,
         line_stroke_width: line_stroke_width,
         line_class: line_class,
         line_fill: line_fill,
         line_stroke_linecap: line_stroke_linecap,
         line_stroke_linejoin: line_stroke_linejoin
       }) do
    ~s|stroke="#{line_stroke}" class="#{line_class}" stroke-width="#{line_stroke_width}" fill="#{line_fill}" stroke-linecap="#{line_stroke_linecap}" stroke-linejoin="#{line_stroke_linejoin}" vector-effect="non-scaling-stroke" |
  end

  defp get_area_style(%Sparkline{
         area_fill: area_fill,
         area_stroke: area_stroke,
         area_class: area_class
       }) do
    ~s|stroke="#{area_stroke}" fill="#{area_fill}" class="#{area_class}"|
  end

  defp get_area_path(%Sparkline{} = sparkline) do
    # Same as the open path, except we drop down, run back to height,height (aka 0,0) and close it...
    open_path = get_line_path(sparkline)
    [open_path, "V 0 L 0 0 Z"]
  end

  # This is the IO List approach
  defp get_line_path(%Sparkline{y_transform: transform_func} = sparkline) do
    last_item_index = Enum.count(sparkline.data) - 1

    [
      "M",
      sparkline.data
      |> Enum.with_index(fn value, index ->
        case index < last_item_index do
          true -> "#{index} #{transform_func.(value)} L "
          _ -> "#{index} #{transform_func.(value)} "
        end
      end)
    ]
  end
end
