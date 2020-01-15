defmodule Contex.PointPlot do

  alias __MODULE__
  alias Contex.{Scale, ContinuousScale, TimeScale}
  alias Contex.CategoryColourScale
  alias Contex.Dataset
  alias Contex.Axis

  defstruct [:data, :width, :height, :x_col, :y_col, :fill_col, :size_col, :x_scale, :y_scale, :fill_scale]

  def new(%Dataset{} = data, width, height) do
    %PointPlot{data: data, width: width, height: height}
  end

  def defaults(%PointPlot{} = plot) do
    x_col_index = 0
    y_col_index = 1

    x_col_name = Dataset.column_name(plot.data, x_col_index)
    y_col_name = Dataset.column_name(plot.data, y_col_index)

    plot
    |> set_x_col_name(x_col_name)
    |> set_y_col_name(y_col_name)
  end

  def set_size(%PointPlot{} = plot, width, height) do
    # We pretend to set the x & y columns to force a recalculation of scales - may be expensive.
    # We only really need to set the range, not recalculate the domain
    %{plot | width: width, height: height}
    |> set_x_col_name(plot.x_col)
    |> set_y_col_name(plot.y_col)
  end

  def get_svg_legend(%PointPlot{fill_scale: scale}) do
    Contex.Legend.to_svg(scale)
  end

  def to_svg(%PointPlot{x_scale: x_scale, y_scale: y_scale} = plot) do
    axis_x = get_x_axis(x_scale, plot.height)
    axis_y = Axis.new_left_axis(y_scale) |> Axis.set_offset(plot.width)

    [
      Axis.to_svg(axis_x),
      Axis.to_svg(axis_y),
      "<g>",
      get_svg_points(plot),
      "</g>",
      get_svg_line(plot)
    ]
  end

  defp get_x_axis(x_scale, offset) do
    axis
      = Axis.new_bottom_axis(x_scale)
        |> Axis.set_offset(offset)

    case length(Scale.ticks_range(x_scale)) > 8 do
      true -> %{axis | rotation: 45}
      _ -> axis
    end
  end

  defp get_svg_points(%PointPlot{data: dataset} = plot) do
    x_col_index = Dataset.column_index(dataset, plot.x_col)
    y_col_index = Dataset.column_index(dataset, plot.y_col)
    fill_col_index = Dataset.column_index(dataset, plot.fill_col)

    dataset.data
    |> Enum.map(fn row -> get_svg_point(row, plot, x_col_index, y_col_index, fill_col_index) end)
  end

  defp get_svg_line(%PointPlot{data: dataset, x_scale: x_scale, y_scale: y_scale} = plot) do
    x_col_index = Dataset.column_index(dataset, plot.x_col)
    y_col_index = Dataset.column_index(dataset, plot.y_col)
    x_tx_fn = x_scale.domain_to_range_fn
    y_tx_fn = y_scale.domain_to_range_fn

    style = ~s|stroke="red" stroke-width="2" fill="none" stroke-dasharray="13,2" stroke-linejoin="round" |

    last_item = Enum.count(dataset.data) - 1
    path = ["M",
        dataset.data
         |> Enum.map(fn row ->
              x = Dataset.value(row, x_col_index)
              y = Dataset.value(row, y_col_index)
              {x_tx_fn.(x), y_tx_fn.(y)}
            end)
         |> Enum.with_index()
         |> Enum.map(fn {{x_plot, y_plot}, i} ->
            case i < last_item do
              true -> ~s|#{x_plot} #{y_plot} L |
              _ -> ~s|#{x_plot} #{y_plot}|
            end
          end)
    ]

    [~s|<path d="|, path, ~s|"|, style, "></path>"]
  end


  defp get_svg_point(row, %PointPlot{x_scale: x_scale, y_scale: y_scale, fill_scale: fill_scale}, x_col_index, y_col_index, fill_col_index) do
    x_data = Dataset.value(row, x_col_index)
    y_data = Dataset.value(row, y_col_index)
    fill_data = Dataset.value(row, fill_col_index)

    x = x_scale.domain_to_range_fn.(x_data)
    y = y_scale.domain_to_range_fn.(y_data)
    fill = CategoryColourScale.colour_for_value(fill_scale, fill_data)

    get_svg_point(x, y, fill)
end

  defp get_svg_point(x, y, fill) when is_number(x) and is_number(y) do
    [~s|<circle cx="#{x}" cy="#{y}"|, ~s| r="3" style="fill: ##{fill};"></circle>|]
  end
  defp get_svg_point(_x, _y, _fill), do: ""

  def set_x_col_name(%PointPlot{width: width} = plot, x_col_name) do
    x_scale = create_scale_for_column(plot.data, x_col_name, {0, width})
    %{plot | x_col: x_col_name, x_scale: x_scale}
  end

  def set_y_col_name(%PointPlot{height: height} = plot, y_col_name) do
    y_scale = create_scale_for_column(plot.data, y_col_name, {height, 0})
    %{plot | y_col: y_col_name, y_scale: y_scale}
  end

  defp create_scale_for_column(data, column, {r_min, r_max}) do
    {min, max} = Dataset.column_extents(data, column)

    case Dataset.guess_column_type(data, column) do
      :datetime ->
        TimeScale.new() |> TimeScale.domain(min, max) |> Scale.set_range(r_min, r_max)
      :number ->
        ContinuousScale.new_linear() |> ContinuousScale.domain(min, max) |> Scale.set_range(r_min, r_max)
    end
  end

  def set_colour_col_name(%PointPlot{} = plot, colour_col_name) do
    vals = Dataset.unique_values(plot.data, colour_col_name)
    colour_scale = CategoryColourScale.new(vals)

    %{plot | fill_col: colour_col_name, fill_scale: colour_scale}
  end

  def set_x_range(%PointPlot{x_scale: scale} = plot, start, finish) when not is_nil(scale) do
    %{plot | x_scale: Scale.set_range(scale, start, finish)}
  end

  def set_y_range(%PointPlot{y_scale: scale} = plot, start, finish) when not is_nil(scale) do
    %{plot | y_scale: Scale.set_range(scale, start, finish)}
  end
end
