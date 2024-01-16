defmodule Contex.OHLC do
  @moduledoc """
  An open-high-low-close plot suitable for displaying stock/share prices
  over time.

  The following columns are required in your dataset mapping:
  - datetime
  - open
  - high
  - low
  - close

  You can elect to plot as candles or ticks.

  If close is higher than open, the candle or line will be plotted in green.
  If close is lower than open, the candle or line will be plotted in red.
  If they are equal, the candle will be plotted in dark grey.

  The datetime column must be of consist of DateTime or NaiveDateTime entries.
  If a custom x scale option is not provided, a `Contex.TimeScale` scale will automatically be generated from the datetime extents
  of the dataset and used for the x-axis.

  The open / high / low / close columns must be of a numeric type (float or integer).
  Decimals are not currently supported.

  If a custom x scale option is not provided, a linear y-axis scale will be automatically
  generated to handle the extents of the data.
  """

  # todo:
  # - refactor :tick into :bar

  import Contex.SVG
  import Extructure

  alias __MODULE__
  alias Contex.{Scale, ContinuousLinearScale, TimeScale}
  alias Contex.{Dataset, Mapping}
  alias Contex.Axis
  alias Contex.Utils

  defstruct [
    :dataset,
    :mapping,
    :options,
    :x_scale,
    :y_scale,
    transforms: %{}
  ]

  @type t() :: %__MODULE__{}
  @typep row() :: list()
  @typep rendered_row() :: list()
  @typep color() :: <<_::24>>

  @typep y_vals() ::
           %{
             open: number(),
             high: number(),
             low: number(),
             close: number()
           }

  @green "00AA00"
  @red "AA0000"
  @black "000000"

  @required_mappings [
    datetime: :exactly_one,
    open: :exactly_one,
    high: :exactly_one,
    low: :exactly_one,
    close: :exactly_one
  ]

  @default_options [
    axis_label_rotation: :auto,
    style: :candle,
    custom_x_scale: nil,
    custom_y_scale: nil,
    custom_x_formatter: nil,
    custom_y_formatter: nil,
    width: 100,
    height: 100,
    zoom: 3,
    bull_color: @green,
    bear_color: @red,
    shadow_color: @black
  ]

  @default_plot_options %{
    show_x_axis: true,
    show_y_axis: true,
    legend_setting: :legend_none
  }

  @zoom_levels [
                 [body_width: 0, spacing: 0],
                 [body_width: 0, spacing: 1],
                 [body_width: 1, spacing: 1],
                 [body_width: 3, spacing: 3],
                 [body_width: 9, spacing: 5],
                 [body_width: 23, spacing: 7]
               ]
               |> Stream.with_index()
               |> Map.new(fn {k, v} -> {v, Map.new(k)} end)

  @doc """
  Create a new `OHLC` struct from Dataset.

  Options may be passed to control the settings for the chart. Options available are:

    - `:style` : `:candle` (default) or `:tick` - display style

    in addition to the common options

  An example:
        data = [
          [~N[2023-12-28 00:00:00], "AAPL", 34049900, 194.14, 194.66, 193.17, 193.58],
          [~N[2023-12-27 00:00:00], "AAPL", 48087680, 192.49, 193.50, 191.09, 193.15],
          [~N[2023-12-26 00:00:00], "AAPL", 28919310, 193.61, 193.89, 192.83, 193.05],
          [~N[2023-12-25 00:00:00], "AAPL", 37149570, 195.18, 195.41, 192.97, 193.60],
          [~N[2023-12-24 00:00:00], "AAPL", 46482550, 196.10, 197.08, 193.50, 194.68],
          [~N[2023-12-23 00:00:00], "AAPL", 52242820, 196.90, 197.68, 194.83, 194.83],
          [~N[2023-12-22 00:00:00], "AAPL", 40714050, 196.16, 196.95, 195.89, 196.94],
          [~N[2023-12-21 00:00:00], "AAPL", 55751860, 196.09, 196.63, 194.39, 195.89],
        ]

        dataset = Dataset.new(data, ["Date", "Ticker", "Volume", "Open", "High", "Low", "Close"])

        opts = [
          mapping: %{datetime: "Date", open: "Open", high: "High", low: "Low", close: "Close"},
          style: :tick,
          title: "AAPL"
        ]

        Contex.Plot.new(dataset, Contex.OHLC, 600, 400, opts)
  """
  @spec new(Contex.Dataset.t(), keyword()) :: Contex.OHLC.t()
  def new(%Dataset{} = dataset, options \\ []) do
    options = Keyword.merge(@default_options, options)
    mapping = Mapping.new(@required_mappings, Keyword.get(options, :mapping), dataset)

    %OHLC{dataset: dataset, mapping: mapping, options: options}
  end

  @doc false
  def set_size(%__MODULE__{} = chart, width, height) do
    chart
    |> set_option(:width, width)
    |> set_option(:height, height)
  end

  @doc false
  def get_legend_scales(%__MODULE__{} = _chart) do
    []
  end

  @spec set_option(t(), atom(), any()) :: t()
  defp set_option(plot, key, value) do
    update(plot, :options, &Keyword.put(&1, key, value))
  end

  @spec get_option(t(), atom()) :: term()
  defp get_option(plot, key) do
    Keyword.get(plot.options, key)
  end

  @doc false
  def to_svg(%__MODULE__{} = plot, plot_options) do
    plot = prepare_scales(plot)
    [x_scale, y_scale] <~ plot

    plot_options = Map.merge(@default_plot_options, plot_options)

    x_axis_svg =
      if plot_options.show_x_axis,
        do:
          get_x_axis(x_scale, plot)
          |> Axis.to_svg(),
        else: ""

    y_axis_svg =
      if plot_options.show_y_axis,
        do:
          Axis.new_left_axis(y_scale)
          |> Axis.set_offset(get_option(plot, :width))
          |> Axis.to_svg(),
        else: ""

    [
      x_axis_svg,
      y_axis_svg,
      "<g>",
      render_data(plot),
      "</g>"
    ]
  end

  @spec render_data(t()) :: [rendered_row()]
  defp render_data(plot) do
    [dataset] <~ plot

    dataset.data
    |> Enum.map(fn row -> render_row(plot, row) end)
  end

  @spec render_row(t(), row()) :: rendered_row()
  defp render_row(plot, row) do
    [transforms, mapping: [accessors], options: options = %{}] <~ plot

    x =
      accessors.datetime.(row)
      |> transforms.x.()

    y_vals = get_y_vals(row, accessors)

    scaled_y_vals =
      Map.new(y_vals, fn {k, v} ->
        {k, transforms.y.(v)}
      end)

    color = get_colour(y_vals, plot)
    draw_row(options, x, scaled_y_vals, color)
  end

  # Draws a grey line from low to high, then overlay a coloured rect
  # for open / close if `:candle` style.
  # Draws a grey line from low to high, and tick from left for open
  # and to right for close if `:tick` style.
  @spec draw_row(map(), number(), y_vals(), color()) :: rendered_row()
  defp draw_row(options, x, y_map, body_color)

  defp draw_row(%{style: :candle} = options, x, y_map, body_color) do
    [zoom, shadow_color, crisp_edges(false), body_border(false)] <~ options
    [body_width] <~ @zoom_levels[zoom]
    [open, high, low, close] <~ y_map

    bar_x = {x - body_width, x + body_width}

    body_opts =
      [
        fill: body_color,
        stroke: body_border && shadow_color,
        shape_rendering: crisp_edges && "crispEdges"
      ]
      |> Enum.filter(&elem(&1, 1))

    style =
      [
        ~s|style="stroke: ##{shadow_color}"|,
        (crisp_edges && ~s| shape-rendering="crispEdges"|) || ""
      ]
      |> Enum.join()

    [
      ~s|<line x1="#{x}" x2="#{x}" y1="#{low}" y2="#{high}" #{style} />|,
      rect(bar_x, {open, close}, "", body_opts)
    ]
  end

  defp draw_row(%{style: :tick} = options, x, y_map, body_color) do
    [zoom, shadow_color, crisp_edges(false), colorized_bars(false)] <~ options
    [body_width] <~ @zoom_levels[zoom]
    [open, high, low, close] <~ y_map

    style =
      [
        ~s|style="stroke: ##{(colorized_bars && body_color) || shadow_color}"|,
        (crisp_edges && ~s| shape-rendering="crispEdges"|) || ""
      ]
      |> Enum.join()

    [
      ~s|<line x1="#{x}" x2="#{x}" y1="#{low}" y2="#{high}" #{style} />|,
      ~s|<line x1="#{x - body_width}" x2="#{x}" y1="#{open}" y2="#{open}"  #{style}" />|,
      ~s|<line x1="#{x}" x2="#{x + body_width}" y1="#{close}" y2="#{close}"  #{style}" />|
    ]
  end

  @spec get_y_vals(row(), %{atom() => (row() -> number())}) :: y_vals()
  defp get_y_vals(row, accessors) do
    [:open, :high, :low, :close]
    |> Enum.map(fn col ->
      y = accessors[col].(row)

      {col, y}
    end)
    |> Enum.into(%{})
  end

  @spec get_colour(y_vals(), t()) :: color()
  defp get_colour(y_map, plot) do
    [bull_color, bear_color, shadow_color] <~ plot.options
    [open, close] <~ y_map

    cond do
      close > open -> bull_color
      close < open -> bear_color
      true -> shadow_color
    end
  end

  @spec get_x_axis(Contex.TimeScale.t(), t()) :: Contex.Axis.t()
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

  @doc false
  def prepare_scales(%__MODULE__{} = plot) do
    plot
    |> prepare_x_scale()
    |> prepare_y_scale()
  end

  @spec prepare_x_scale(t()) :: t()
  defp prepare_x_scale(%__MODULE__{dataset: dataset, mapping: mapping} = plot) do
    x_col_name = mapping.column_map[:datetime]
    width = get_option(plot, :width)
    custom_x_scale = get_option(plot, :custom_x_scale)

    x_scale =
      case custom_x_scale do
        nil -> create_timescale_for_column(dataset, x_col_name, {0, width})
        _ -> custom_x_scale |> Scale.set_range(0, width)
      end

    x_scale = %{x_scale | custom_tick_formatter: get_option(plot, :custom_x_formatter)}
    x_transform = Scale.domain_to_range_fn(x_scale)
    transforms = Map.merge(plot.transforms, %{x: x_transform})

    %{plot | x_scale: x_scale, transforms: transforms}
  end

  defp create_timescale_for_column(dataset, column, {r_min, r_max}) do
    {min, max} = Dataset.column_extents(dataset, column)

    TimeScale.new()
    |> TimeScale.domain(min, max)
    |> Scale.set_range(r_min, r_max)
  end

  @spec prepare_y_scale(t()) :: t()
  defp prepare_y_scale(plot) do
    [dataset, mapping: [column_map]] <~ plot

    y_col_names = Enum.map([:open, :high, :low, :close], &column_map[&1])
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

  # TODO: Extract into Dataset
  defp get_overall_domain(dataset, col_names) do
    combiner = fn {min1, max1}, {min2, max2} ->
      {Utils.safe_min(min1, min2), Utils.safe_max(max1, max2)}
    end

    Enum.reduce(col_names, {nil, nil}, fn col, acc_extents ->
      inner_extents = Dataset.column_extents(dataset, col)
      combiner.(acc_extents, inner_extents)
    end)
  end

  @spec update(t(), atom(), (term() -> term())) :: t()
  defp update(plot, field, updater) do
    struct!(plot, %{field => updater.(Map.fetch!(plot, field))})
  end
end
