defmodule Contex.GanttChart do
  @moduledoc """
  Generates a Gantt Chart.

  Bars are drawn for each task covering the start and end time for each task. In addition, tasks can be grouped
  into categories which have a different coloured background - this is useful for showing projects that are
  in major phases.

  The time interval columns must be of a date time type (either `NaiveDateTime` or `DateTime`)

  Labels can optionally be drawn for each task (use `show_task_labels/2`) and a description for each task, including
  the time interval is generated and added as a '&lt;title&gt;' element attached to the bar. Most browsers provide
  a tooltip functionality to display the title when the mouse hovers over the containing element.

  By default, the first four columns of the supplied dataset are used for the category, task, start time and end time.
  """

  import Contex.SVG

  alias __MODULE__
  alias Contex.{Scale, OrdinalScale, TimeScale, CategoryColourScale}
  alias Contex.{Dataset, Mapping}
  alias Contex.Axis
  alias Contex.Utils

  defstruct [
    :dataset,
    :mapping,
    :time_scale,
    :task_scale,
    :category_scale,
    :phx_event_handler,
    width: 100,
    height: 100,
    show_task_labels: true,
    padding: 2
  ]

  @required_mappings [
    category_col: :exactly_one,
    task_col: :exactly_one,
    start_col: :exactly_one,
    finish_col: :exactly_one,
    id_col: :zero_or_one
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Create a new Gantt Chart definition and apply defaults.

  If the data in the dataset is stored as a list of maps, the `:mapping` option is required. This value must be a map of the plot's `:category_col`, `:task_col`, `:start_col` and `:finish_col` keys, and optionally an `:id_col` key.

  For example:

  `mapping: %{category_col: :category, task_col: :task_name, start_col: :start_time, end_col: :end_time, id_col: :task_id}`
  """
  @spec new(Contex.Dataset.t(), keyword()) :: Contex.GanttChart.t()
  def new(%Dataset{} = dataset, options \\ []) do
    mapping = Mapping.new(@required_mappings, Keyword.get(options, :mapping), dataset)

    %GanttChart{dataset: dataset, mapping: mapping}
    |> set_default_scales()
  end

  @doc """
  Sets the default scales for the plot based on its column mapping.
  """
  @spec set_default_scales(Contex.GanttChart.t()) :: Contex.GanttChart.t()
  def set_default_scales(%GanttChart{mapping: %{column_map: column_map}} = plot) do
    set_category_task_cols(plot, column_map.category_col, column_map.task_col)
    |> set_task_interval_cols({column_map.start_col, column_map.finish_col})
  end

  @doc """
  Show or hide labels on the bar for each task
  """
  @spec show_task_labels(Contex.GanttChart.t(), boolean()) :: Contex.GanttChart.t()
  def show_task_labels(%GanttChart{} = plot, show_task_labels) do
    %{plot | show_task_labels: show_task_labels}
  end

  @doc false
  def set_size(%GanttChart{mapping: %{column_map: column_map}} = plot, width, height) do
    # We pretend to set columns to force a recalculation of scales - may be expensive.
    # We only really need to set the range, not recalculate the domain
    %{plot | width: width, height: height}
    |> set_category_task_cols(column_map.category_col, column_map.task_col)
    |> set_task_interval_cols({column_map.start_col, column_map.finish_col})
  end

  @doc """
  Specify the columns used for category and task
  """
  @spec set_category_task_cols(
          Contex.GanttChart.t(),
          Contex.Dataset.column_name(),
          Contex.Dataset.column_name()
        ) ::
          Contex.GanttChart.t()
  def set_category_task_cols(
        %GanttChart{dataset: dataset, height: height, padding: padding, mapping: mapping} = plot,
        cat_col_name,
        task_col_name
      ) do
    mapping = Mapping.update(mapping, %{category_col: cat_col_name, task_col: task_col_name})

    tasks = Dataset.unique_values(dataset, task_col_name)
    categories = Dataset.unique_values(dataset, cat_col_name)

    task_scale =
      OrdinalScale.new(tasks)
      |> Scale.set_range(0, height)
      |> OrdinalScale.padding(padding)

    cat_scale = CategoryColourScale.new(categories)

    %{plot | task_scale: task_scale, category_scale: cat_scale, mapping: mapping}
  end

  @doc """
  Specify the columns used for start and end time of each task.
  """
  @spec set_task_interval_cols(
          Contex.GanttChart.t(),
          {Contex.Dataset.column_name(), Contex.Dataset.column_name()}
        ) ::
          Contex.GanttChart.t()
  def set_task_interval_cols(
        %GanttChart{dataset: dataset, width: width, mapping: mapping} = plot,
        {start_col_name, finish_col_name}
      ) do
    mapping = Mapping.update(mapping, %{start_col: start_col_name, finish_col: finish_col_name})
    {min, _} = Dataset.column_extents(dataset, start_col_name)
    {_, max} = Dataset.column_extents(dataset, finish_col_name)

    time_scale =
      TimeScale.new()
      |> TimeScale.domain(min, max)
      |> Scale.set_range(0, width)

    %{plot | time_scale: time_scale, mapping: mapping}
  end

  @doc """
  Optionally specify a LiveView event handler. This attaches a `phx-click` attribute to each bar element. Note that it may
  not work with some browsers (e.g. Safari on iOS).
  """
  @spec event_handler(Contex.GanttChart.t(), String.t()) :: Contex.GanttChart.t()
  def event_handler(%GanttChart{} = plot, event_handler) do
    %{plot | phx_event_handler: event_handler}
  end

  @doc """
  If id_col is set it is used as the value sent by the phx_event_handler.
  Otherwise, the category and task is used
  """
  @spec set_id_col(Contex.GanttChart.t(), Contex.Dataset.column_name()) :: Contex.GanttChart.t()
  def set_id_col(%GanttChart{mapping: mapping} = plot, id_col_name) do
    %{plot | mapping: Mapping.update(mapping, %{id_col: id_col_name})}
  end

  @doc false
  def to_svg(%GanttChart{time_scale: time_scale} = plot, _options) do
    time_axis = Axis.new_bottom_axis(time_scale) |> Axis.set_offset(plot.height)
    toptime_axis = Axis.new_top_axis(time_scale) |> Axis.set_offset(plot.height)
    toptime_axis = %{toptime_axis | tick_size_inner: 3, tick_padding: 1}

    [
      get_category_rects_svg(plot),
      Axis.to_svg(toptime_axis),
      Axis.to_svg(time_axis),
      Axis.gridlines_to_svg(time_axis),
      "<g>",
      get_svg_bars(plot),
      "</g>"
    ]
  end

  defp get_category_rects_svg(
         %GanttChart{mapping: mapping, dataset: dataset, category_scale: cat_scale} = plot
       ) do
    categories = Dataset.unique_values(dataset, mapping.column_map.category_col)

    Enum.map(categories, fn cat ->
      fill = CategoryColourScale.colour_for_value(cat_scale, cat)
      band = get_category_band(plot, cat) |> adjust_category_band()
      x_extents = {0, plot.width}

      # TODO: When we have a colour manipulation library we can fade the colour. Until then, we'll draw a transparent white box on top
      [
        rect(x_extents, band, "", fill: fill, opacity: "0.2"),
        rect(x_extents, band, "", fill: "FFFFFF", opacity: "0.3"),
        get_category_tick_svg(cat, band)
      ]
    end)
  end

  # Adjust band to fill gap
  defp adjust_category_band({y1, y2}), do: {y1 - 1, y2 + 1}

  defp get_category_tick_svg(text, {_min_y, max_y} = _band) do
    # y = midpoint(band)
    y = max_y

    [
      ~s|<g class="exc-tick" font-size="10" text-anchor="start" transform="translate(0, #{y})">|,
      text(text, x: "2", dy: "-0.32em", alignment_baseline: "baseline"),
      "</g>"
    ]
  end

  defp get_svg_bars(%GanttChart{dataset: dataset} = plot) do
    dataset.data
    |> Enum.map(fn row -> get_svg_bar(row, plot) end)
  end

  defp get_svg_bar(
         row,
         %GanttChart{
           mapping: mapping,
           task_scale: task_scale,
           time_scale: time_scale,
           category_scale: cat_scale
         } = plot
       ) do
    task_data = mapping.accessors.task_col.(row)
    cat_data = mapping.accessors.category_col.(row)
    start_time = mapping.accessors.start_col.(row)
    end_time = mapping.accessors.finish_col.(row)
    title = ~s|#{task_data}: #{start_time} -> #{end_time}|

    task_band = OrdinalScale.get_band(task_scale, task_data)
    fill = CategoryColourScale.colour_for_value(cat_scale, cat_data)
    start_x = Scale.domain_to_range(time_scale, start_time)
    end_x = Scale.domain_to_range(time_scale, end_time)

    opts = get_bar_event_handler_opts(row, plot, cat_data, task_data) ++ [fill: fill]

    [
      rect({start_x, end_x}, task_band, title(title), opts),
      get_svg_bar_label(plot, {start_x, end_x}, task_data, task_band)
    ]
  end

  defp get_svg_bar_label(%GanttChart{show_task_labels: false}, _, _, _), do: ""

  defp get_svg_bar_label(_plot, {bar_start, bar_end} = bar, label, band) do
    text_y = midpoint(band)
    width = width(bar)

    {text_x, class, anchor} =
      case width < 50 do
        true -> {bar_end + 2, "exc-barlabel-out", "start"}
        _ -> {bar_start + 5, "exc-barlabel-in", "start"}
      end

    text(text_x, text_y, label, anchor: anchor, dominant_baseline: "central", class: class)
  end

  defp get_bar_event_handler_opts(
         _row,
         %GanttChart{
           mapping: %{column_map: %{id_col: nil}},
           phx_event_handler: phx_event_handler
         },
         category,
         task
       )
       when is_binary(phx_event_handler) and phx_event_handler != "" do
    [category: "#{category}", task: task, phx_click: phx_event_handler]
  end

  defp get_bar_event_handler_opts(
         row,
         %GanttChart{mapping: mapping, phx_event_handler: phx_event_handler},
         _category,
         _task
       )
       when is_binary(phx_event_handler) and phx_event_handler != "" do
    id = mapping.accessors.id_col.(row)

    [id: "#{id}", phx_click: phx_event_handler]
  end

  defp get_bar_event_handler_opts(_row, %GanttChart{} = _plot, _category, _task), do: []

  defp get_category_band(
         %GanttChart{mapping: mapping, task_scale: task_scale, dataset: dataset},
         category
       ) do
    Enum.reduce(dataset.data, {nil, nil}, fn row, {min, max} = acc ->
      task = mapping.accessors.task_col.(row)
      cat = mapping.accessors.category_col.(row)

      case cat == category do
        false ->
          {min, max}

        _ ->
          task_band = OrdinalScale.get_band(task_scale, task)
          max_band(acc, task_band)
      end
    end)
  end

  defp midpoint({a, b}), do: (a + b) / 2.0
  defp width({a, b}), do: abs(a - b)
  defp max_band({a1, b1}, {a2, b2}), do: {Utils.safe_min(a1, a2), Utils.safe_max(b1, b2)}
end
