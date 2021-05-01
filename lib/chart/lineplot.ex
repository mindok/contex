defmodule Contex.LinePlot do
  @moduledoc """
  A simple point plot, plotting points showing y values against x values.

  It is possible to specify multiple y columns with the same x column. It is not
  yet possible to specify multiple independent series.

  Data are sorted by the x-value prior to plotting.

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

  defstruct [
    :dataset,
    :mapping,
    :options,
    :x_scale,
    :y_scale,
    :legend_scale,
    transforms: %{},
    colour_palette: :default
  ]

  @required_mappings [
    x_col: :exactly_one,
    y_cols: :one_or_more,
    fill_col: :zero_or_one
  ]

  @default_options [
    axis_label_rotation: :auto,
    custom_x_scale: nil,
    custom_y_scale: nil,
    custom_x_formatter: nil,
    custom_y_formatter: nil,
    width: 100,
    height: 100,
    smoothed: true,
    stroke_width: "2",
    colour_palette: :default
  ]

  @type t() :: %__MODULE__{}

  @doc ~S"""
  Create a new point plot definition and apply defaults.

    Options may be passed to control the settings for the barchart. Options available are:

    - `:axis_label_rotation` : `:auto` (default), 45 or 90

  Specifies the label rotation value that will be applied to the bottom axis. Accepts integer
  values for degrees of rotation or `:auto`. Note that manually set rotation values other than
  45 or 90 will be treated as zero. The default value is `:auto`, which sets the rotation to
  zero degrees if the number of items on the axis is greater than eight, 45 degrees otherwise.

    - `:custom_x_scale` : `nil` (default) or an instance of a suitable `Contex.Scale`.

    The scale must be suitable for the data type and would typically be either `Contex.ContinuousLinearScale`
    or `Contex.TimeScale`. It is not necessary to set the range for the scale as the range is set
    as part of the chart layout process.

    - `:custom_y_scale` : `nil` (default) or an instance of a suitable `Contex.Scale`.

    - `:custom_x_formatter` : `nil` (default) or a function with arity 1

  Allows the axis tick labels to be overridden. For example, if you have a numeric representation of money and you want to
  have the x axis show it as millions of dollars you might do something like:

        # Turns 1_234_567.67 into $1.23M
        defp money_formatter_millions(value) when is_number(value) do
          "$#{:erlang.float_to_binary(value/1_000_000.0, [decimals: 2])}M"
        end

        defp show_chart(data) do
          LinePlot.new(
            dataset,
            mapping: %{x_col: :column_a, y_cols: [:column_b, column_c]},
            custom_x_formatter: &money_formatter_millions/1
          )
        end

    - `:custom_y_formatter` : `nil` (default) or a function with arity 1.

    - `:stroke_width` : 2 (default) - stroke width of the line

    - `:smoothed` : true (default) or false - draw the lines smoothed

  Note that the smoothing algorithm is a cardinal spline with tension = 0.3.
  You may get strange effects (e.g. loops / backtracks) in certain circumstances, e.g.
  if the x-value spacing is very uneven. This alogorithm forces the smoothed line
  through the points.

    - `:colour_palette` : `:default` (default) or colour palette - see `colours/2`

  Overrides the default colours.

  Where multiple y columns are defined for the plot, a different colour will be used for
  each column.

  If a single y column is defined and a `:fill_col`column is mapped,
  a different colour will be used for each unique value in the colour column.

  If a single y column is defined and no `:fill_col`column is mapped, the first colour
  in the supplied colour palette will be used to plot the points.

  Colours can either be a named palette defined in `Contex.CategoryColourScale` or a list of strings representing hex code
  of the colour as per CSS colour hex codes, but without the #. For example:

    ```
    chart = LinePlot.new(
        dataset,
        mapping: %{x_col: :column_a, y_cols: [:column_b, column_c]},
        colour_palette: ["fbb4ae", "b3cde3", "ccebc5"]
      )
    ```
    The colours will be applied to the data series in the same order as the columns are specified in `set_val_col_names/2`

    - `:mapping` : Maps attributes required to generate the barchart to columns in the dataset.

  If the data in the dataset is stored as a map, the `:mapping` option is required. If the dataset
  is not stored as a map, `:mapping` may be left out, in which case the first column will be used
  for the x and the second column used as the y.
  This value must be a map of the plot's `:x_col` and `:y_cols` to keys in the map,
  such as `%{x_col: :column_a, y_cols: [:column_b, column_c]}`.
  The value for the `:y_cols` key must be a list.

  If a single y column is specified an optional `:fill_col` mapping can be provided
  to control the point colour. _This is ignored if there are multiple y columns_.

  """
  @spec new(Contex.Dataset.t(), keyword()) :: Contex.LinePlot.t()
  def new(%Dataset{} = dataset, options \\ []) do
    options = Keyword.merge(@default_options, options)
    mapping = Mapping.new(@required_mappings, Keyword.get(options, :mapping), dataset)

    %LinePlot{dataset: dataset, mapping: mapping, options: options}
  end

  @doc false
  def set_size(%LinePlot{} = plot, width, height) do
    plot
    |> set_option(:width, width)
    |> set_option(:height, height)
  end

  defp set_option(%LinePlot{options: options} = plot, key, value) do
    options = Keyword.put(options, key, value)

    %{plot | options: options}
  end

  defp get_option(%LinePlot{options: options}, key) do
    Keyword.get(options, key)
  end

  @doc false
  def get_svg_legend(%LinePlot{} = plot) do
    plot = prepare_scales(plot)
    Contex.Legend.to_svg(plot.legend_scale)
  end

  def get_svg_legend(_), do: ""

  @doc false
  def to_svg(%LinePlot{} = plot) do
    plot = prepare_scales(plot)
    x_scale = plot.x_scale
    y_scale = plot.y_scale

    axis_x = get_x_axis(x_scale, plot)
    axis_y = Axis.new_left_axis(y_scale) |> Axis.set_offset(get_option(plot, :width))

    [
      Axis.to_svg(axis_x),
      Axis.to_svg(axis_y),
      "<g>",
      get_svg_lines(plot),
      "</g>"
    ]
  end

  defp get_x_axis(x_scale, plot) do
    rotation =
      case get_option(plot, :axis_label_rotation) do
        :auto ->
          if length(Scale.ticks_range(x_scale)) > 8, do: 45, else: 0

        degrees ->
          degrees
      end

    x_scale
    |> Axis.new_bottom_axis()
    |> Axis.set_offset(get_option(plot, :height))
    |> Kernel.struct(rotation: rotation)
  end

  defp get_svg_lines(
         %LinePlot{dataset: dataset, mapping: %{accessors: accessors}, transforms: transforms} =
           plot
       ) do
    x_accessor = accessors.x_col

    # Pre-sort by x-value else we get squiggly lines
    data = Enum.sort(dataset.data, fn a, b -> x_accessor.(a) > x_accessor.(b) end)

    Enum.with_index(accessors.y_cols)
    |> Enum.map(fn {y_accessor, index} ->
      colour = transforms.colour.(index, nil)
      get_svg_line(plot, data, y_accessor, colour)
    end)
  end

  defp get_svg_line(
         %LinePlot{mapping: %{accessors: accessors}, transforms: transforms} = plot,
         data,
         y_accessor,
         colour
       ) do
    smooth = get_option(plot, :smoothed)
    stroke_width = get_option(plot, :stroke_width)

    options = [
      transparent: true,
      stroke: colour,
      stroke_width: stroke_width,
      stroke_linejoin: "round"
    ]

    points_list =
      data
      |> Stream.map(fn row ->
        x =
          accessors.x_col.(row)
          |> transforms.x.()

        y =
          y_accessor.(row)
          |> transforms.y.()

        {x, y}
      end)
      |> Enum.filter(fn {x, _y} -> not is_nil(x) end)
      |> Enum.sort(fn {x1, _y1}, {x2, _y2} -> x1 < x2 end)
      |> Enum.chunk_by(fn {_x, y} -> is_nil(y) end)
      |> Enum.filter(fn [{_x, y} | _] -> not is_nil(y) end)

    Enum.map(points_list, fn points -> line(points, smooth, options) end)
  end

  @doc false
  def prepare_scales(%LinePlot{} = plot) do
    plot
    |> prepare_x_scale()
    |> prepare_y_scale()
    |> prepare_colour_scale()
  end

  defp prepare_x_scale(%LinePlot{dataset: dataset, mapping: mapping} = plot) do
    x_col_name = mapping.column_map[:x_col]
    width = get_option(plot, :width)
    custom_x_scale = get_option(plot, :custom_x_scale)

    x_scale =
      case custom_x_scale do
        nil -> create_scale_for_column(dataset, x_col_name, {0, width})
        _ -> custom_x_scale |> Scale.set_range(0, width)
      end

    x_scale = %{x_scale | custom_tick_formatter: get_option(plot, :custom_x_formatter)}
    x_transform = Scale.domain_to_range_fn(x_scale)
    transforms = Map.merge(plot.transforms, %{x: x_transform})

    %{plot | x_scale: x_scale, transforms: transforms}
  end

  defp prepare_y_scale(%LinePlot{dataset: dataset, mapping: mapping} = plot) do
    y_col_names = mapping.column_map[:y_cols]
    height = get_option(plot, :height)
    custom_y_scale = get_option(plot, :custom_y_scale)

    y_scale =
      case custom_y_scale do
        nil ->
          {min, max} =
            get_overall_domain(dataset, y_col_names)
            |> Utils.fixup_value_range()

          ContinuousLinearScale.new()
          |> ContinuousLinearScale.domain(min, max)
          |> Scale.set_range(height, 0)

        _ ->
          custom_y_scale |> Scale.set_range(height, 0)
      end

    y_scale = %{y_scale | custom_tick_formatter: get_option(plot, :custom_y_formatter)}
    y_transform = Scale.domain_to_range_fn(y_scale)
    transforms = Map.merge(plot.transforms, %{y: y_transform})

    %{plot | y_scale: y_scale, transforms: transforms}
  end

  defp prepare_colour_scale(%LinePlot{dataset: dataset, mapping: mapping} = plot) do
    y_col_names = mapping.column_map[:y_cols]
    fill_col_name = mapping.column_map[:fill_col]
    palette = get_option(plot, :colour_palette)

    # It's a little tricky. We look up colours by index when colouring by series
    # but need the legend by column name, so where we are colouring by series
    # we will create a transform function with one instance of a colour scale
    # and the legend from another

    legend_scale = create_legend_colour_scale(y_col_names, fill_col_name, dataset, palette)

    transform = create_colour_transform(y_col_names, fill_col_name, dataset, palette)
    transforms = Map.merge(plot.transforms, %{colour: transform})

    %{plot | legend_scale: legend_scale, transforms: transforms}
  end

  defp create_legend_colour_scale(y_col_names, fill_col_name, dataset, palette)
       when length(y_col_names) == 1 and not is_nil(fill_col_name) do
    vals = Dataset.unique_values(dataset, fill_col_name)
    CategoryColourScale.new(vals) |> CategoryColourScale.set_palette(palette)
  end

  defp create_legend_colour_scale(y_col_names, _fill_col_name, _dataset, palette) do
    CategoryColourScale.new(y_col_names) |> CategoryColourScale.set_palette(palette)
  end

  defp create_colour_transform(y_col_names, fill_col_name, dataset, palette)
       when length(y_col_names) == 1 and not is_nil(fill_col_name) do
    vals = Dataset.unique_values(dataset, fill_col_name)
    scale = CategoryColourScale.new(vals) |> CategoryColourScale.set_palette(palette)

    fn _col_index, fill_val -> CategoryColourScale.colour_for_value(scale, fill_val) end
  end

  defp create_colour_transform(y_col_names, _fill_col_name, _dataset, palette) do
    fill_indices =
      Enum.with_index(y_col_names)
      |> Enum.map(fn {_, index} -> index end)

    scale = CategoryColourScale.new(fill_indices) |> CategoryColourScale.set_palette(palette)

    fn col_index, _fill_val -> CategoryColourScale.colour_for_value(scale, col_index) end
  end

  defp get_overall_domain(dataset, col_names) do
    combiner = fn {min1, max1}, {min2, max2} ->
      {Utils.safe_min(min1, min2), Utils.safe_max(max1, max2)}
    end

    Enum.reduce(col_names, {nil, nil}, fn col, acc_extents ->
      inner_extents = Dataset.column_extents(dataset, col)
      combiner.(acc_extents, inner_extents)
    end)
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
end
