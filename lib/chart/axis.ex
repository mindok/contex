defmodule Contex.Axis do
  @moduledoc """
  `Contex.Axis` represents the visual appearance of a `Contex.Scale`

  In general terms, an Axis is responsible for rendering a `Contex.Scale` where the scale is used to position
  a graphical element.

  As an end-user of the Contex you won't need to worry too much about Axes - the specific
  plot types take care of them. Things like styling and scales are handled elsewhere. However,
  if you are building a new plot type you will need to understand how they work.

  Axes can be drawn with ticks in different locations relative to the Axis based on the orientation.
  For example, when `:orientation` is `:top`, the axis is drawn as a horizontal line with the ticks
  above and the tick text above that.

  `:rotation` is used to optionally rotate the labels and can either by 45 or 90 (anything else is considered to be 0).

  `:tick_size_inner` and `:tick_size_outer` control the line lengths of the ticks.

  `:tick_padding` controls the gap between the end of the tick mark and the tick text.

  `:flip_factor` is for internal use. Whatever you set it to will be ignored.

  An offset relative to the containing SVG element's origin is used to position the axis line.
  For example, an x-axis drawn at the bottom of the plot will typically be offset by the height
  of the plot content. The different plot types look after this internally.

  There are some layout heuristics to calculate text sizes and offsets based on axis orientation and whether the
  tick labels are rotated.
  """

  alias __MODULE__
  alias Contex.Scale

  defstruct [
    :scale,
    :orientation,
    rotation: 0,
    tick_size_inner: 6,
    tick_size_outer: 6,
    tick_padding: 3,
    flip_factor: 1,
    offset: 0
  ]

  @orientations [:top, :left, :right, :bottom]

  @type t() :: %__MODULE__{}
  @type orientations() :: :top | :left | :right | :bottom

  @doc """
  Create a new axis struct with orientation being one of :top, :left, :right, :bottom
  """
  @spec new(Contex.Scale.t(), orientations()) :: __MODULE__.t()
  def new(scale, orientation) when orientation in @orientations do
    if is_nil(Contex.Scale.impl_for(scale)) do
      raise ArgumentError, message: "scale must implement Contex.Scale protocol"
    end

    %Axis{scale: scale, orientation: orientation}
  end

  @doc """
  Create a new axis struct with orientation set to `:top`.

  Equivalent to `Axis.new(scale, :top)`
  """
  @spec new_top_axis(Contex.Scale.t()) :: __MODULE__.t()
  def new_top_axis(scale), do: new(scale, :top)

  @doc """
  Create a new axis struct with orientation set to `:bottom`.

  Equivalent to `Axis.new(scale, :bottom)`
  """
  @spec new_bottom_axis(Contex.Scale.t()) :: __MODULE__.t()
  def new_bottom_axis(scale), do: new(scale, :bottom)

  @doc """
  Create a new axis struct with orientation set to `:left`.

  Equivalent to `Axis.new(scale, :left)`
  """
  @spec new_left_axis(Contex.Scale.t()) :: __MODULE__.t()
  def new_left_axis(scale), do: new(scale, :left)

  @doc """
  Create a new axis struct with orientation set to `:right`.

  Equivalent to `Axis.new(scale, :right)`
  """
  @spec new_right_axis(Contex.Scale.t()) :: __MODULE__.t()
  def new_right_axis(scale), do: new(scale, :right)

  @doc """
  Sets the offset for where the axis will be drawn. The offset will either be horizontal
  or vertical depending on the orientation of the axis.
  """
  @spec set_offset(__MODULE__.t(), number()) :: __MODULE__.t()
  def set_offset(%Axis{} = axis, offset) do
    %{axis | offset: offset}
  end

  @doc """
  Generates the SVG content for the axis (axis line, tick mark, tick labels). The coordinate system
  will be in the coordinate system of the containing plot (i.e. the range of the `Contex.Scale` specified for the axis)
  """
  def to_svg(%Axis{scale: scale} = axis) do
    # Returns IO List for axis. Assumes the containing group handles the transform to the correct location
    axis = %{axis | flip_factor: get_flip_factor(axis.orientation)}
    {range0, range1} = get_adjusted_range(scale)

    [
      "<g ",
      get_svg_axis_location(axis),
      ~s| fill="none" font-size="10" text-anchor="#{get_text_anchor(axis)}">|,
      ~s|<path class="exc-domain" stroke="#000" d="#{get_svg_axis_line(axis, range0, range1)}"></path>|,
      get_svg_tickmarks(axis),
      "</g>"
    ]
  end

  @doc """
  Generates grid-lines for each tick in the `Contex.Scale` specified for the axis.
  """
  def gridlines_to_svg(%Axis{} = axis) do
    [
      "<g> ",
      get_svg_gridlines(axis),
      "</g>"
    ]
  end

  defp get_svg_gridlines(%Axis{scale: scale} = axis) do
    domain_ticks = Scale.ticks_domain(scale)
    domain_to_range_fn = Scale.domain_to_range_fn(scale)

    domain_ticks
    # Don't render first tick as it should be on the axis
    |> Enum.drop(1)
    |> Enum.map(fn tick -> get_svg_gridline(axis, domain_to_range_fn.(tick)) end)
  end

  defp get_svg_gridline(%Axis{offset: offset} = axis, location) do
    dim_length = get_tick_dimension(axis)

    dim_constant =
      case dim_length do
        "x" -> "y"
        "y" -> "x"
      end

    # Nudge to render better
    location = location + 0.5

    [
      ~s|<line class="exc-grid" stroke-dasharray="3,3"|,
      ~s| #{dim_constant}1="#{location}" #{dim_constant}2="#{location}"|,
      ~s| #{dim_length}1="0" #{dim_length}2="#{offset}"></line>|
    ]
  end

  defp get_svg_axis_location(%Axis{orientation: orientation}) when orientation in [:top, :left] do
    " "
  end

  defp get_svg_axis_location(%Axis{:orientation => :bottom, offset: offset}) do
    ~s|transform="translate(0, #{offset})"|
  end

  defp get_svg_axis_location(%Axis{:orientation => :right, offset: offset}) do
    ~s|transform="translate(#{offset}, 0)"|
  end

  defp get_text_anchor(%Axis{orientation: orientation}) do
    case orientation do
      :right -> "start"
      :left -> "end"
      _ -> "middle"
    end
  end

  defp get_svg_axis_line(%Axis{orientation: orientation} = axis, range0, range1)
       when orientation in [:right, :left] do
    %Axis{tick_size_outer: tick_size_outer, flip_factor: k} = axis
    ~s|M#{k * tick_size_outer},#{range0}H0.5V#{range1}H#{k * tick_size_outer}|
  end

  defp get_svg_axis_line(%Axis{orientation: orientation} = axis, range0, range1)
       when orientation in [:top, :bottom] do
    %Axis{tick_size_outer: tick_size_outer, flip_factor: k} = axis
    ~s|M#{range0}, #{k * tick_size_outer}V0.5H#{range1}V#{k * tick_size_outer}|
  end

  defp get_svg_tickmarks(%Axis{scale: scale} = axis) do
    domain_ticks = Scale.ticks_domain(scale)
    domain_to_range_fn = Scale.domain_to_range_fn(scale)

    domain_ticks
    |> Enum.map(fn tick -> get_svg_tick(axis, tick, domain_to_range_fn.(tick)) end)
  end

  defp get_svg_tick(%Axis{orientation: orientation} = axis, tick, range_tick) do
    # Approach is to calculate transform for the tick and render tick mark with text in one go
    [
      ~s|<g class="exc-tick" opacity="1" transform=|,
      get_svg_tick_transform(orientation, range_tick),
      ">",
      get_svg_tick_line(axis),
      get_svg_tick_label(axis, tick),
      "</g>"
    ]
  end

  defp get_svg_tick_transform(orientation, range_tick) when orientation in [:top, :bottom] do
    ~s|"translate(#{range_tick + 0.5},0)"|
  end

  defp get_svg_tick_transform(orientation, range_tick) when orientation in [:left, :right] do
    ~s|"translate(0, #{range_tick + 0.5})"|
  end

  defp get_svg_tick_line(%Axis{flip_factor: k, tick_size_inner: size} = axis) do
    dim = get_tick_dimension(axis)
    ~s|<line #{dim}2="#{k * size}"></line>|
  end

  defp get_svg_tick_label(%Axis{flip_factor: k, scale: scale} = axis, tick) do
    offset = axis.tick_size_inner + axis.tick_padding
    dim = get_tick_dimension(axis)
    text_adjust = get_svg_tick_text_adjust(axis)

    tick =
      Scale.get_formatted_tick(scale, tick)
      |> Contex.SVG.Sanitize.basic_sanitize()

    ~s|<text #{dim}="#{k * offset}" #{text_adjust}>#{tick}</text>|
  end

  defp get_tick_dimension(%Axis{orientation: orientation}) when orientation in [:top, :bottom],
    do: "y"

  defp get_tick_dimension(%Axis{orientation: orientation}) when orientation in [:left, :right],
    do: "x"

  defp get_svg_tick_text_adjust(%Axis{orientation: orientation})
       when orientation in [:left, :right],
       do: ~s|dy="0.32em"|

  defp get_svg_tick_text_adjust(%Axis{orientation: :top}), do: ""

  defp get_svg_tick_text_adjust(%Axis{orientation: :bottom, rotation: 45}) do
    ~s|dy="-0.1em" dx="-0.9em" text-anchor="end" transform="rotate(-45)"|
  end

  defp get_svg_tick_text_adjust(%Axis{orientation: :bottom, rotation: 90}) do
    ~s|dy="-0.51em" dx="-0.9em" text-anchor="end" transform="rotate(-90)"|
  end

  defp get_svg_tick_text_adjust(%Axis{orientation: :bottom}) do
    ~s|dy="0.71em" dx="0" text-anchor="middle"|
  end

  # NOTE: Recipes for rotates labels on bottom axis:
  # -90 dy="-0.51em" dx="-0.91em" text-anchor="end"
  # -45 dy="-0.1em" dx="-0.91em" text-anchor="end"
  # 0 dy="-0.71em" dx="0" text-anchor="middle"

  defp get_flip_factor(orientation) when orientation in [:top, :left], do: -1

  defp get_flip_factor(orientation) when orientation in [:right, :bottom], do: 1

  # TODO: We should only nudge things half a pixel for odd line widths. This is to stop fuzzy lines
  defp get_adjusted_range(scale) do
    {min_r, max_r} = Scale.get_range(scale)
    {min_r + 0.5, max_r + 0.5}
  end
end
