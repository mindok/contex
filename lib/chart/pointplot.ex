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
  alias Contex.{Dataset, Mapping}
  alias Contex.Axis
  alias Contex.Utils

  defstruct [:dataset, :mapping, :x_scale, :y_scale, :fill_scale, transforms: %{}, width: 100, height: 100, colour_palette: :default]

  @required_mappings [:x_col, :y_cols]
  @optional_mappings [:fill_col]

  @type t() :: %__MODULE__{}

  @doc """
  Create a new point plot definition and apply defaults. If the data in the dataset is stored as a list of maps, the `:series_mapping` option is required. This value must be a map of the plot's `:x_col` and `:y_cols` to keys in the map, such as `%{x_col: :column_a, y_cols: [:column_b, column_c]}`. The `:y_cols` value must be a list.
  """
  @spec new(Contex.Dataset.t(), keyword()) :: Contex.PointPlot.t()
  def new(dataset, options \\ [])

  def new(%Dataset{data: [first_row | _rest]} = dataset, options) when is_map(first_row) do
    case Keyword.get(options, :mapping) do
      nil ->
        raise(ArgumentError, "Mapping must be provided with map data.")

      %{fill_col: _fill_col} = column_map ->
        %PointPlot{dataset: dataset}
        |> Mapping.map!(column_map)
        |> set_default_scales()
        |> set_colour_col_name(column_map.fill_col)

      column_map ->
        column_map = Map.merge(%{fill_col: nil}, column_map)
        %PointPlot{dataset: dataset}
        |> Mapping.map!(column_map)
        |> set_default_scales()
    end
  end

  def new(%Dataset{} = dataset, _options) do
    %PointPlot{dataset: dataset}
    |> Mapping.map!(default_mapping(dataset))
    |> set_default_scales()
  end

  @doc false
  def required_mappings(), do: @required_mappings

  @doc false
  def optional_mappings(), do: @optional_mappings

  @doc """
  Sets the default scales for the plot based on its column mapping.
  """
  @spec set_default_scales(Contex.PointPlot.t()) :: Contex.PointPlot.t()
  def set_default_scales(%PointPlot{mapping: %{column_map: column_map}} = plot) do
    set_x_col_name(plot, column_map.x_col)
    |> set_y_col_names(column_map.y_cols)
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
    |> set_y_col_names(plot.mapping.column_map.y_cols)
  end
  def colours(plot, _) do
    %{plot | colour_palette: :default}
    |> set_y_col_names(plot.mapping.column_map.y_cols)
  end

  @doc false
  def set_size(%PointPlot{mapping: %{column_map: column_map}} = plot, width, height) do
    # We pretend to set the x & y columns to force a recalculation of scales - may be expensive.
    # We only really need to set the range, not recalculate the domain
    %{plot | width: width, height: height}
    |> set_x_col_name(column_map.x_col)
    |> set_y_col_names(column_map.y_cols)
  end

  @doc false
  def get_svg_legend(%PointPlot{mapping: %{column_map: %{y_cols: y_cols, fill_col: fill_col}}} = plot) when length(y_cols) > 0 or is_nil(fill_col) do
    # We do the point plotting with an index to look up the colours. For the legend we need the names
    series_fill_colours =
      CategoryColourScale.new(y_cols)
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
    ]
  end

  defp default_mapping(%Dataset{} = dataset) do
    %{
      x_col: Dataset.column_name(dataset, 0),
      y_cols: [Dataset.column_name(dataset, 1)],
      fill_col: nil
    }
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

  defp get_svg_points(%PointPlot{dataset: dataset} = plot) do
    dataset.data
    |> Enum.map(fn row -> get_svg_point(plot, row) end)
  end

  # defp get_svg_line(%PointPlot{dataset: dataset, x_scale: x_scale, y_scale: y_scale} = plot) do
  #   x_col_index = Dataset.column_index(dataset, plot.x_col)
  #   y_col_index = Dataset.column_index(dataset, plot.y_col)
  #   x_tx_fn = Scale.domain_to_range_fn(x_scale)
  #   y_tx_fn = Scale.domain_to_range_fn(y_scale)

  #   style = ~s|stroke="red" stroke-width="2" fill="none" stroke-dasharray="13,2" stroke-linejoin="round" |

  #   last_item = Enum.count(dataset.data) - 1
  #   path = ["M",
  #       dataset.data
  #        |> Stream.map(fn row ->
  #             x = Dataset.value(row, x_col_index)
  #             y = Dataset.value(row, y_col_index)
  #             {x_tx_fn.(x), y_tx_fn.(y)}
  #           end)
  #        |> Stream.with_index()
  #        |> Enum.map(fn {{x_plot, y_plot}, i} ->
  #           case i < last_item do
  #             true -> ~s|#{x_plot} #{y_plot} L |
  #             _ -> ~s|#{x_plot} #{y_plot}|
  #           end
  #         end)
  #   ]

  #   [~s|<path d="|, path, ~s|"|, style, "></path>"]
  # end

  defp get_svg_point(%PointPlot{mapping: %{accessors: accessors, column_map: %{y_cols: y_cols}}, transforms: transforms, fill_scale: fill_scale}, row) when length(y_cols) == 1 do
    x =
      accessors.x_col.(row)
      |> transforms.x.()

    y =
      hd(accessors.y_cols).(row)
      |> transforms.y.()

    fill_data =
      case accessors.fill_col.(row) do
        nil -> 0
        val -> val
      end

    fill = CategoryColourScale.colour_for_value(fill_scale, fill_data)

    get_svg_point(x, y, fill)
  end

  defp get_svg_point(%PointPlot{mapping: %{accessors: accessors}, transforms: transforms, fill_scale: fill_scale}, row) do
    x =
      accessors.x_col.(row)
      |> transforms.x.()

    Enum.with_index(accessors.y_cols)
    |> Enum.map(fn {accessor, index} ->
         y = accessor.(row) |> transforms.y.()
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
  def set_x_col_name(%PointPlot{dataset: dataset, width: width} = plot, x_col_name) do
    plot = Mapping.map!(plot, %{x_col: x_col_name})

    x_scale = create_scale_for_column(dataset, x_col_name, {0, width})
    x_transform = Scale.domain_to_range_fn(x_scale)
    transforms = Map.merge(plot.transforms, %{x: x_transform})

    %{plot | x_scale: x_scale, transforms: transforms}
  end

  @doc """
  Specify which column(s) in the dataset is/are used for the y values.

  These columns must contain numeric data.

  Where more than one y column is specified the colours are used to identify data from
  each column.
  """
  @spec set_y_col_names(Contex.PointPlot.t(), [Contex.Dataset.column_name()]) :: Contex.PointPlot.t()
  def set_y_col_names(%PointPlot{dataset: dataset, height: height} = plot, y_col_names) when is_list(y_col_names) do
    plot = Mapping.map!(plot, %{y_cols: y_col_names})
    {min, max} =
      get_overall_domain(dataset, y_col_names)
      |> Utils.fixup_value_range()

    y_scale =
      ContinuousLinearScale.new()
      |> ContinuousLinearScale.domain(min, max)
      |> Scale.set_range(height, 0)

    y_transform = Scale.domain_to_range_fn(y_scale)
    transforms = Map.merge(plot.transforms, %{y: y_transform})

    fill_indices =
      Enum.with_index(y_col_names)
      |> Enum.map(fn {_, index} -> index end)

    series_fill_colours =
      CategoryColourScale.new(fill_indices)
      |> CategoryColourScale.set_palette(plot.colour_palette)

    %{plot | y_scale: y_scale, transforms: transforms, fill_scale: series_fill_colours}
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
  def set_colour_col_name(%PointPlot{dataset: dataset}=plot, fill_col_name) do
    plot = Mapping.map!(plot, %{fill_col: fill_col_name})
    vals = Dataset.unique_values(dataset, fill_col_name)
    colour_scale = CategoryColourScale.new(vals)
    %{plot | fill_scale: colour_scale}
  end
end
