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
    :options,
    :time_scale,
    :task_scale,
    :category_scale
  ]

  @required_mappings [
    category_col: :exactly_one,
    task_col: :exactly_one,
    start_col: :exactly_one,
    finish_col: :exactly_one,
    id_col: :zero_or_one
  ]

  @default_options [
    width: 100,
    height: 100,
    show_task_labels: true,
    padding: 2,
    colour_palette: :default,
    phx_event_handler: nil,
    phx_event_target: nil
  ]

  @type t() :: %__MODULE__{}

  @doc ~S"""
  Creates a new Gantt chart from a dataset and sets defaults.

  Options may be passed to control the settings for the barchart. Options available are:

    - `:padding` : integer (default 2) - Specifies the padding between the task bars. Defaults to 2. Specified relative to the plot size.
    - `:show_task_labels` : `true` (default) or false - display labels for each task
    - `:colour_palette` : `:default` (default) or colour palette - see `colours/2`

  Overrides the default colours.

  Colours can either be a named palette defined in `Contex.CategoryColourScale` or a list of strings representing hex code
  of the colour as per CSS colour hex codes, but without the #. For example:

    ```
    gantt = GanttChart.new(
        dataset,
        mapping: %{category_col: :category, task_col: :task_name, start_col: :start_time, finish_col: :end_time, id_col: :task_id},
        colour_palette: ["fbb4ae", "b3cde3", "ccebc5"]
      )
    ```

    The colours will be applied to the data series in the same order as the columns are specified in `set_val_col_names/2`

    - `:phx_event_handler` : `nil` (default) or string representing `phx-click` event handler
    - `:phx_event_target` : `nil` (default) or string representing `phx-target` for handler

  Optionally specify a LiveView event handler. This attaches a `phx-click` attribute to each bar element.
  You can specify the event_target for LiveComponents - a `phx-target` attribute will also be attached.

  Note that it may not work with some browsers (e.g. Safari on iOS).

    - `:mapping` : Maps attributes required to generate the barchart to columns in the dataset.

  If the data in the dataset is stored as a map, the `:mapping` option is required. If the dataset
  is not stored as a map, `:mapping` may be left out, in which case the columns will be assigned
  in order to category, task, start time, finish time, task id.

  If a mapping is explicit (recommended) the value must be a map of the plot's
  `:category_col`, `:task_col`, `:start_col`, `:finish_col`, `:id_col` to keys in the map,

  For example:

  `mapping: %{category_col: :category, task_col: :task_name, start_col: :start_time, finish_col: :end_time, id_col: :task_id}`
  """
  @spec new(Contex.Dataset.t(), keyword()) :: Contex.GanttChart.t()
  def new(%Dataset{} = dataset, options \\ []) do
    options = Keyword.merge(@default_options, options)
    mapping = Mapping.new(@required_mappings, Keyword.get(options, :mapping), dataset)

    %GanttChart{dataset: dataset, mapping: mapping, options: options}
  end

  @doc """
  Sets the default scales for the plot based on its column mapping.
  """
  @deprecated "Default scales are now silently applied"
  @spec set_default_scales(Contex.GanttChart.t()) :: Contex.GanttChart.t()
  def set_default_scales(%GanttChart{mapping: %{column_map: column_map}} = plot) do
    set_category_task_cols(plot, column_map.category_col, column_map.task_col)
    |> set_task_interval_cols({column_map.start_col, column_map.finish_col})
  end

  @doc """
  Show or hide labels on the bar for each task
  """
  @deprecated "Set in new/2 options"
  @spec show_task_labels(Contex.GanttChart.t(), boolean()) :: Contex.GanttChart.t()
  def show_task_labels(%GanttChart{} = plot, show_task_labels) do
    set_option(plot, :show_task_labels, show_task_labels)
  end

  @doc false
  def set_size(%GanttChart{} = plot, width, height) do
    plot
    |> set_option(:width, width)
    |> set_option(:height, height)
  end

  @doc """
  Specify the columns used for category and task
  """
  @deprecated "Use `:mapping` option in `new/2`"
  @spec set_category_task_cols(
          Contex.GanttChart.t(),
          Contex.Dataset.column_name(),
          Contex.Dataset.column_name()
        ) ::
          Contex.GanttChart.t()
  def set_category_task_cols(%GanttChart{mapping: mapping} = plot, cat_col_name, task_col_name) do
    mapping = Mapping.update(mapping, %{category_col: cat_col_name, task_col: task_col_name})

    %{plot | mapping: mapping}
  end

  @doc """
  Specify the columns used for start and end time of each task.
  """
  @deprecated "Use `:mapping` option in `new/2`"
  @spec set_task_interval_cols(
          Contex.GanttChart.t(),
          {Contex.Dataset.column_name(), Contex.Dataset.column_name()}
        ) ::
          Contex.GanttChart.t()
  def set_task_interval_cols(
        %GanttChart{mapping: mapping} = plot,
        {start_col_name, finish_col_name}
      ) do
    mapping = Mapping.update(mapping, %{start_col: start_col_name, finish_col: finish_col_name})

    %{plot | mapping: mapping}
  end

  defp prepare_scales(%GanttChart{} = plot) do
    plot
    |> prepare_time_scale()
    |> prepare_task_scale()
    |> prepare_category_scale()
  end

  defp prepare_task_scale(%GanttChart{dataset: dataset, mapping: mapping} = plot) do
    task_col_name = mapping.column_map[:task_col]
    height = get_option(plot, :height)
    padding = get_option(plot, :padding)

    tasks = Dataset.unique_values(dataset, task_col_name)

    task_scale =
      OrdinalScale.new(tasks)
      |> Scale.set_range(0, height)
      |> OrdinalScale.padding(padding)

    %{plot | task_scale: task_scale}
  end

  defp prepare_category_scale(%GanttChart{dataset: dataset, mapping: mapping} = plot) do
    cat_col_name = mapping.column_map[:category_col]
    colour_palette = get_option(plot, :colour_palette)
    categories = Dataset.unique_values(dataset, cat_col_name)

    cat_scale = CategoryColourScale.new(categories, colour_palette)

    %{plot | category_scale: cat_scale}
  end

  defp prepare_time_scale(%GanttChart{dataset: dataset, mapping: mapping} = plot) do
    start_col_name = mapping.column_map[:start_col]
    finish_col_name = mapping.column_map[:finish_col]
    width = get_option(plot, :width)

    {min, _} = Dataset.column_extents(dataset, start_col_name)
    {_, max} = Dataset.column_extents(dataset, finish_col_name)

    time_scale =
      TimeScale.new()
      |> TimeScale.domain(min, max)
      |> Scale.set_range(0, width)

    %{plot | time_scale: time_scale}
  end

  @doc """
  Optionally specify a LiveView event handler. This attaches a `phx-click` attribute to each bar element.
  You can specify the event_target for LiveComponents - a `phx-target` attribute will also be attached.

  Note that it may not work with some browsers (e.g. Safari on iOS).
  """
  @deprecated "Set in new/2 options"
  def event_handler(%GanttChart{} = plot, event_handler, event_target \\ nil) do
    plot
    |> set_option(:phx_event_handler, event_handler)
    |> set_option(:phx_event_target, event_target)
  end

  @doc """
  If id_col is set it is used as the value sent by the phx_event_handler.
  Otherwise, the category and task is used
  """
  @deprecated "Use `:mapping` option in `new/2`"
  @spec set_id_col(Contex.GanttChart.t(), Contex.Dataset.column_name()) :: Contex.GanttChart.t()
  def set_id_col(%GanttChart{mapping: mapping} = plot, id_col_name) do
    %{plot | mapping: Mapping.update(mapping, %{id_col: id_col_name})}
  end

  defp set_option(%GanttChart{options: options} = plot, key, value) do
    options = Keyword.put(options, key, value)

    %{plot | options: options}
  end

  defp get_option(%GanttChart{options: options}, key) do
    Keyword.get(options, key)
  end

  @doc false
  def to_svg(%GanttChart{} = plot, _options) do
    plot = prepare_scales(plot)
    time_scale = plot.time_scale
    height = get_option(plot, :height)
    time_axis = Axis.new_bottom_axis(time_scale) |> Axis.set_offset(height)
    toptime_axis = Axis.new_top_axis(time_scale) |> Axis.set_offset(height)
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
      x_extents = {0, get_option(plot, :width)}

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

  defp get_svg_bar_label(plot, {bar_start, bar_end} = bar, label, band) do
    case get_option(plot, :show_task_labels) do
      true ->
        text_y = midpoint(band)
        width = width(bar)

        {text_x, class, anchor} =
          case width < 50 do
            true -> {bar_end + 2, "exc-barlabel-out", "start"}
            _ -> {bar_start + 5, "exc-barlabel-in", "start"}
          end

        text(text_x, text_y, label, anchor: anchor, dominant_baseline: "central", class: class)

      _ ->
        ""
    end
  end

  defp get_bar_event_handler_opts(row, %GanttChart{} = plot, category, task) do
    handler = get_option(plot, :phx_event_handler)
    target = get_option(plot, :phx_event_target)

    base_opts =
      case target do
        nil -> [phx_click: handler]
        "" -> [phx_click: handler]
        _ -> [phx_click: handler, phx_target: target]
      end

    id_opts = get_bar_click_id(row, plot, category, task)

    case handler do
      nil -> []
      "" -> []
      _ -> Keyword.merge(base_opts, id_opts)
    end
  end

  defp get_bar_click_id(
         _row,
         %GanttChart{
           mapping: %{column_map: %{id_col: nil}}
         },
         category,
         task
       ) do
    [category: "#{category}", task: task]
  end

  defp get_bar_click_id(
         row,
         %GanttChart{mapping: mapping},
         _category,
         _task
       ) do
    id = mapping.accessors.id_col.(row)

    [id: "#{id}"]
  end

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
