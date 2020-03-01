defmodule Contex.PointPlot do
@moduledoc """
A simple point plot, plotting points showing y values against x values.

It is possible to specify multiple y columns with the same x column. It is not
yet possible to specify multiple independent series.

The x column can either be numeric or date time data. If numeric, a
`Contex.ContinuousLinearScale` is used to scale the values to the plot,
and if date time, a `Contex.TimeScale` is used.

Fill colours for each y column can be specified with `colours/2`.

A column in the dataset can optionally be used to control the colours. See
`colours/2` and `set_colour_col_name/2`
"""

  import Contex.SVG

  alias __MODULE__
  alias Contex.{Scale, ContinuousLinearScale, TimeScale}
  alias Contex.CategoryColourScale
  alias Contex.Dataset
  alias Contex.Axis
  alias Contex.Utils

  defstruct [:dataset, :width, :height, :x_col, :y_cols, :fill_col, :size_col, :x_scale, :y_scale, :fill_scale, :colour_palette]

  @type t() :: %__MODULE__{}

  @doc """
  Create a new point plot definition and apply defaults.
  """
  @spec new(Contex.Dataset.t(), keyword()) :: Contex.PointPlot.t()
  def new(%Dataset{} = dataset, _options \\ []) do
    %PointPlot{dataset: dataset, width: 100, height: 100}
    |> defaults()
  end

  @doc """
  Sets the default values for the plot.

  By default, the first column in the dataset is used for the x values and the second column
  for the y values.

  The colour palette is set to :default.
  """
  @spec defaults(Contex.PointPlot.t()) :: Contex.PointPlot.t()
  def defaults(%PointPlot{} = plot) do
    x_col_index = 0
    y_col_index = 1

    x_col_name = Dataset.column_name(plot.dataset, x_col_index)
    y_col_names = [Dataset.column_name(plot.dataset, y_col_index)]

    %{plot | colour_palette: :default}
    |> set_x_col_name(x_col_name)
    |> set_y_col_names(y_col_names)
  end

  @doc """
  Set the colour palette for fill colours.

  Where multiple y columns are defined for the plot, a different colour will be used for
  each column.

  If a single y column is defined and a colour column is defined (see `set_colour_col_name/2`),
  a different colour will be used for each unique value in the colour column.

  If a single y column is defined and no colour column is defined, the first colour
  in the supplied colour palette will be used to plot the points.
  """
  @spec colours(Contex.PointPlot.t(), Contex.CategoryColourScale.colour_palette()) :: Contex.PointPlot.t()
  def colours(plot, colour_palette) when is_list(colour_palette) or is_atom(colour_palette) do
    %{plot | colour_palette: colour_palette}
    |> set_y_col_names(plot.y_cols)
  end
  def colours(plot, _) do
    %{plot | colour_palette: :default}
    |> set_y_col_names(plot.y_cols)
  end

  @doc false
  def set_size(%PointPlot{} = plot, width, height) do
    # We pretend to set the x & y columns to force a recalculation of scales - may be expensive.
    # We only really need to set the range, not recalculate the domain
    %{plot | width: width, height: height}
    |> set_x_col_name(plot.x_col)
    |> set_y_col_names(plot.y_cols)
  end

  @doc false
  def get_svg_legend(%PointPlot{y_cols: y_cols, fill_col: fill_col}=plot) when length(y_cols) > 0 or is_nil(fill_col) do
    # We do the point plotting with a index to look up the colours. For the legend we need the names
    series_fill_colours
      = CategoryColourScale.new(y_cols)
      |> CategoryColourScale.set_palette(plot.colour_palette)

    Contex.Legend.to_svg(series_fill_colours)
  end
  def get_svg_legend(%PointPlot{fill_scale: scale}) do
      Contex.Legend.to_svg(scale)
  end
  def get_svg_legend(_), do: ""

  @doc false
  def to_svg(%PointPlot{x_scale: x_scale, y_scale: y_scale} = plot) do
    axis_x = get_x_axis(x_scale, plot.height)
    axis_y = Axis.new_left_axis(y_scale) |> Axis.set_offset(plot.width)

    [
      Axis.to_svg(axis_x),
      Axis.to_svg(axis_y),
      "<g>",
      get_svg_points(plot),
      "</g>"
      #,get_svg_line(plot)
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

  defp get_svg_points(%PointPlot{dataset: dataset, x_scale: x_scale, y_scale: y_scale} = plot) do
    x_tx_fn = Scale.domain_to_range_fn(x_scale)
    y_tx_fn = Scale.domain_to_range_fn(y_scale)

    x_col_index = Dataset.column_index(dataset, plot.x_col)
    y_col_indices = Enum.map(plot.y_cols, fn col -> Dataset.column_index(dataset, col) end)

    fill_col_index = Dataset.column_index(dataset, plot.fill_col)

    dataset.data
    |> Enum.map(fn row ->
      get_svg_point(row, x_tx_fn, y_tx_fn, plot.fill_scale, x_col_index, y_col_indices, fill_col_index)
    end)
  end

  defp get_svg_line(%PointPlot{dataset: dataset, x_scale: x_scale, y_scale: y_scale} = plot) do
    x_col_index = Dataset.column_index(dataset, plot.x_col)
    y_col_index = Dataset.column_index(dataset, plot.y_col)
    x_tx_fn = Scale.domain_to_range_fn(x_scale)
    y_tx_fn = Scale.domain_to_range_fn(y_scale)

    style = ~s|stroke="red" stroke-width="2" fill="none" stroke-dasharray="13,2" stroke-linejoin="round" |

    last_item = Enum.count(dataset.data) - 1
    path = ["M",
        dataset.data
         |> Stream.map(fn row ->
              x = Dataset.value(row, x_col_index)
              y = Dataset.value(row, y_col_index)
              {x_tx_fn.(x), y_tx_fn.(y)}
            end)
         |> Stream.with_index()
         |> Enum.map(fn {{x_plot, y_plot}, i} ->
            case i < last_item do
              true -> ~s|#{x_plot} #{y_plot} L |
              _ -> ~s|#{x_plot} #{y_plot}|
            end
          end)
    ]

    [~s|<path d="|, path, ~s|"|, style, "></path>"]
  end


  defp get_svg_point(row, x_tx_fn, y_tx_fn, fill_scale, x_col_index, [y_col_index]=y_col_indices, fill_col_index) when length(y_col_indices) == 1 do
    x_data = Dataset.value(row, x_col_index)
    y_data = Dataset.value(row, y_col_index)

    fill_data = if is_integer(fill_col_index) and fill_col_index >= 0 do
      Dataset.value(row, fill_col_index)
    else
      0
    end

    x = x_tx_fn.(x_data)
    y = y_tx_fn.(y_data)
    fill = CategoryColourScale.colour_for_value(fill_scale, fill_data)

    get_svg_point(x, y, fill)
  end

  defp get_svg_point(row, x_tx_fn, y_tx_fn, fill_scale, x_col_index, y_col_indices, _fill_col_index) do
    x_data = Dataset.value(row, x_col_index)
    x = x_tx_fn.(x_data)

    Enum.with_index(y_col_indices)
    |> Enum.map(fn {col_index, index} ->
      y_data = Dataset.value(row, col_index)
      y = y_tx_fn.(y_data)
      fill = CategoryColourScale.colour_for_value(fill_scale, index)
      get_svg_point(x, y, fill)
    end)
  end

  defp get_svg_point(x, y, fill) when is_number(x) and is_number(y) do
    circle(x, y, 3, fill: fill)
  end
  defp get_svg_point(_x, _y, _fill), do: ""

  @doc """
  Specify which column in the dataset is used for the x values.

  This column must contain numeric or date time data.
  """
  @spec set_x_col_name(Contex.PointPlot.t(), Contex.Dataset.column_name()) :: Contex.PointPlot.t()
  def set_x_col_name(%PointPlot{width: width} = plot, x_col_name) do
    x_scale = create_scale_for_column(plot.dataset, x_col_name, {0, width})
    %{plot | x_col: x_col_name, x_scale: x_scale}
  end

  @doc """
  Specify which column(s) in the dataset is/are used for the y values.

  These columns must contain numeric data.

  Where more than one y column is specified the colours are used to identify data from
  each column.
  """
  @spec set_y_col_names(Contex.PointPlot.t(), [Contex.Dataset.column_name()]) :: Contex.PointPlot.t()
  def set_y_col_names(%PointPlot{height: height} = plot, y_col_names) when is_list(y_col_names) do
    {min, max} =
      get_overall_domain(plot.dataset, y_col_names)
      |> Utils.fixup_value_range()

    y_scale = ContinuousLinearScale.new()
      |> ContinuousLinearScale.domain(min, max)
      |> Scale.set_range(height, 0)

    fill_indices = Enum.with_index(y_col_names) |> Enum.map(fn {_, index} -> index end)

    series_fill_colours
      = CategoryColourScale.new(fill_indices)
      |> CategoryColourScale.set_palette(plot.colour_palette)

    %{plot | y_cols: y_col_names, y_scale: y_scale, fill_scale: series_fill_colours}
  end

  defp get_overall_domain(dataset, col_names) do
    combiner = fn {min1, max1}, {min2, max2} -> {Utils.safe_min(min1, min2), Utils.safe_max(max1, max2)} end

    Enum.reduce(col_names, {nil, nil}, fn col, acc_extents ->
          inner_extents = Dataset.column_extents(dataset, col)
          combiner.(acc_extents, inner_extents)
        end )
  end

  defp create_scale_for_column(dataset, column, {r_min, r_max}) do
    {min, max} = Dataset.column_extents(dataset, column)

    case Dataset.guess_column_type(dataset, column) do
      :datetime ->
        TimeScale.new()
          |> TimeScale.domain(min, max)
          |> Scale.set_range(r_min, r_max)
      :number ->
        ContinuousLinearScale.new()
          |> ContinuousLinearScale.domain(min, max)
          |> Scale.set_range(r_min, r_max)
    end
  end

  @doc """
  If a single y column is specified, it is possible to use another column to control the point colour.

  Note: This is ignored if there are multiple y columns.
  """
  @spec set_colour_col_name(Contex.PointPlot.t(), Contex.Dataset.column_name()) :: Contex.PointPlot.t()
  def set_colour_col_name(%PointPlot{} = plot, colour_col_name) do
    vals = Dataset.unique_values(plot.dataset, colour_col_name)
    colour_scale = CategoryColourScale.new(vals)

    %{plot | fill_col: colour_col_name, fill_scale: colour_scale}
  end

end
