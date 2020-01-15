defmodule Contex.Axis do
  alias __MODULE__
  alias Contex.Scale

  defstruct [:scale, :orientation, rotation: 0, tick_size_inner: 6, tick_size_outer: 6, tick_padding: 3, flip_factor: 1, offset: 0]

  @orientations [:top, :left, :right, :bottom]


  def new(scale, orientation) when orientation in @orientations do
    %Axis{scale: scale, orientation: orientation}
  end

  def new_top_axis(scale), do: new(scale, :top)
  def new_bottom_axis(scale), do: new(scale, :bottom)
  def new_left_axis(scale), do: new(scale, :left)
  def new_right_axis(scale), do: new(scale, :right)

  def set_offset(%Axis{} = axis, offset) do
    %{axis | offset: offset}
  end

  # Returns IO List for axis. Assumes the containing group handles the transform to the correct location
  def to_svg(%Axis{scale: scale} = axis) do
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
    |> Enum.drop(1) # Don't render first tick as it should be on the axis
    |> Enum.map(fn tick -> get_svg_gridline(axis, domain_to_range_fn.(tick)) end)
  end

  defp get_svg_gridline(%Axis{offset: offset} = axis, location) do
    dim_length = get_tick_dimension(axis)
    dim_constant = case dim_length do
      "x" -> "y"
      "y" -> "x"
    end
    location = location + 0.5 # Nudge to render better

    ~s|<line class="exc-grid" stroke-dasharray="3,3" #{dim_constant}1="#{location}" #{dim_constant}2="#{location}"  #{dim_length}1="0" #{dim_length}2="#{offset}"></line>|
  end


  defp get_svg_axis_location(%Axis{orientation: orientation}) when orientation in [:top, :left] do " " end

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

  defp get_svg_axis_line(%Axis{orientation: orientation, tick_size_outer: tick_size_outer, flip_factor: k}, range0, range1)
       when orientation in [:right, :left] do
    ~s|M#{k * tick_size_outer},#{range0}H0.5V#{range1}H#{k * tick_size_outer}|
  end

  defp get_svg_axis_line(%Axis{orientation: orientation, tick_size_outer: tick_size_outer, flip_factor: k} , range0, range1)
       when orientation in [:top, :bottom] do
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
    [~s|<g class="exc-tick" opacity="1" transform=|,
        get_svg_tick_transform(orientation, range_tick),
      ">",
      get_svg_tick_line(axis),
      get_svg_tick_label(axis, tick),
    "</g>"]
  end

  defp get_svg_tick_transform(orientation, range_tick) when orientation in [:top, :bottom] do ~s|"translate(#{range_tick + 0.5},0)"| end
  defp get_svg_tick_transform(orientation, range_tick) when orientation in [:left, :right] do ~s|"translate(0, #{range_tick + 0.5})"| end

  defp get_svg_tick_line(%Axis{flip_factor: k, tick_size_inner: size} = axis) do
    dim = get_tick_dimension(axis)
    ~s|<line #{dim}2="#{k * size}"></line>|
  end

  defp get_svg_tick_label(%Axis{flip_factor: k, scale: scale} = axis, tick) do
    offset = axis.tick_size_inner + axis.tick_padding
    dim = get_tick_dimension(axis)
    text_adjust = get_svg_tick_text_adjust(axis)

    tick = Scale.get_formatted_tick(scale, tick)

    ~s|<text #{dim}="#{k * offset}" #{text_adjust}>#{tick}</text>|
  end

  defp get_tick_dimension(%Axis{orientation: orientation}) when orientation in [:top, :bottom] do "y" end
  defp get_tick_dimension(%Axis{orientation: orientation}) when orientation in [:left, :right] do "x" end

  defp get_svg_tick_text_adjust(%Axis{orientation: orientation}) when orientation in [:left, :right], do: ~s|dy="0.32em"|
  defp get_svg_tick_text_adjust(%Axis{orientation: :top}), do: ""

  defp get_svg_tick_text_adjust(%Axis{orientation: :bottom, rotation: 45}) do ~s|dy="-0.1em" dx="-0.9em" text-anchor="end" transform="rotate(-45)"| end
  defp get_svg_tick_text_adjust(%Axis{orientation: :bottom, rotation: 90}) do ~s|dy="-0.51em" dx="-0.9em" text-anchor="end" transform="rotate(-90)"| end
  defp get_svg_tick_text_adjust(%Axis{orientation: :bottom}) do ~s|dy="0.71em" dx="0" text-anchor="middle"| end

  #NOTE: Recipes for rotates labels on bottom axis:
  # -90 dy="-0.51em" dx="-0.91em" text-anchor="end"
  # -45 dy="-0.1em" dx="-0.91em" text-anchor="end"
  # 0 dy="-0.71em" dx="0" text-anchor="middle"


  defp get_flip_factor(orientation) when orientation in [:top, :left] do -1 end
  defp get_flip_factor(orientation) when orientation in [:right, :bottom] do 1 end

  #TODO: We should only nudge things half a pixel for odd line widths. This is to stop fuzzy lines
  defp get_adjusted_range(scale) do
    {min_r, max_r} = Scale.get_range(scale)
    {min_r + 0.5, max_r + 0.5}
  end

end
