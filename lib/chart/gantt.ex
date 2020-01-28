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
alias __MODULE__
alias Contex.{Scale, OrdinalScale, TimeScale, CategoryColourScale}
alias Contex.Dataset
alias Contex.Axis
alias Contex.Utils

defstruct [:dataset, :width, :height, :category_col, :task_col, :show_task_labels, :interval_cols, :time_scale, :task_scale, :padding, :category_scale, :phx_event_handler, id_col: ""]

  @doc """
  Create a new Gantt Chart definition and apply defaults.
  """
  @spec new(Contex.Dataset.t()) :: Contex.GanttChart.t()
  def new(%Dataset{} = dataset) do
    %GanttChart{dataset: dataset, width: 100, height: 100}
    |> defaults()
  end

  @doc """
  Sets defaults for the Gantt Chart.

  The first four columns in the dataset are used for category, task, start date/time and end date/time.

  Task labels are enabled by default.
  """
  @spec defaults(Contex.GanttChart.t()) :: Contex.GanttChart.t()
  def defaults(%GanttChart{dataset: dataset} = plot) do
    cat_col_index = 0
    task_col_index = 1
    start_col_index = 2
    end_col_index = 3

    %{plot | padding: 2, show_task_labels: true}
    |> set_category_task_cols(Dataset.column_name(dataset, cat_col_index), Dataset.column_name(dataset, task_col_index))
    |> set_task_interval_cols({Dataset.column_name(dataset, start_col_index), Dataset.column_name(dataset, end_col_index)})
  end

  @doc """
  Show or hide labels on the bar for each task
  """
  @spec show_task_labels(Contex.GanttChart.t(), boolean()) :: Contex.GanttChart.t()
  def show_task_labels(%GanttChart{} = plot, show_task_labels) do
    %{plot | show_task_labels: show_task_labels}
  end

  @doc false
  def set_size(%GanttChart{} = plot, width, height) do
    # We pretend to set columns to force a recalculation of scales - may be expensive.
    # We only really need to set the range, not recalculate the domain
    %{plot | width: width, height: height}
    |> set_category_task_cols(plot.category_col, plot.task_col)
    |> set_task_interval_cols(plot.interval_cols)
  end

  @doc """
  Specify the columns used for category and task
  """
  @spec set_category_task_cols(Contex.GanttChart.t(), Contex.Dataset.column_name(), Contex.Dataset.column_name()) ::
          Contex.GanttChart.t()
  def set_category_task_cols(%GanttChart{dataset: dataset, height: height, padding: padding} = plot, cat_col_name, task_col_name) do
    tasks = Dataset.unique_values(dataset, task_col_name)
    categories = Dataset.unique_values(dataset, cat_col_name)

    task_scale = OrdinalScale.new(tasks)
      |> Scale.set_range(0, height)
      |> OrdinalScale.padding(padding)

    cat_scale = CategoryColourScale.new(categories)

    %{plot | category_col: cat_col_name, task_col: task_col_name , task_scale: task_scale, category_scale: cat_scale}
  end

  @doc """
  Specify the columns used for start and end time of each task.
  """
  @spec set_task_interval_cols(Contex.GanttChart.t(), {Contex.Dataset.column_name(), Contex.Dataset.column_name()}) ::
          Contex.GanttChart.t()
  def set_task_interval_cols(%GanttChart{dataset: dataset, width: width} = plot, {start_col, end_col}) do
    {min, _} = Dataset.column_extents(dataset, start_col)
    {_, max} = Dataset.column_extents(dataset, end_col)

    time_scale =TimeScale.new()
      |> TimeScale.domain(min, max)
      |> Scale.set_range(0, width)

    %{plot | interval_cols: {start_col, end_col}, time_scale: time_scale}
  end

  @doc """
  Optionally specify a LiveView event handler. This attaches a `phx-click` attribute to each bar element. Note that it may
  not work with some browsers (e.g. Safari on iOS).
  """
  @spec event_handler(Contex.GanttChart.t(), String.t()) :: Contex.GanttChart.t()
  def event_handler(%GanttChart{}=plot, event_handler) do
    %{plot | phx_event_handler: event_handler}
  end

  @doc """
  If id_col is set it is used as the value sent by the phx_event_handler.
  Otherwise, the category and task is used
  """
  @spec set_id_col(Contex.GanttChart.t(), Contex.Dataset.column_name()) :: Contex.GanttChart.t()
  def set_id_col(%GanttChart{}=plot, id_col_name) do
    %{plot | id_col: id_col_name}
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

  defp get_category_rects_svg(%GanttChart{dataset: dataset, category_col: cat_col_name, category_scale: cat_scale}=plot) do
    categories = Dataset.unique_values(dataset, cat_col_name)

    Enum.map(categories, fn cat ->
      fill = CategoryColourScale.colour_for_value(cat_scale, cat)
      band = get_category_band(plot, cat)
      width = plot.width
      height = width(band) + 2 # Minor adjustment to remove gap...
      {y, _}=band
      y = y - 1 # Minor adjustment to remove gap...

      # TODO: When we have a colour manipulation library we can fade the colour. Until then, we'll draw a transparent white box on top
      [~s|<rect x="#{0}" y="#{y}" width="#{width}" height="#{height}" style="fill: ##{fill};" fill-opacity="0.2"></rect>|,
      ~s|<rect x="#{0}" y="#{y}" width="#{width}" height="#{height}" style="fill: #FFFFFF;" fill-opacity="0.3"></rect>|,
      get_category_tick_svg(cat, band)]
    end)
  end

  defp get_category_tick_svg(text, {_min_y, max_y}=_band) do
    #y = midpoint(band)
    y = max_y
    [~s|<g class="exc-tick" font-size="10" text-anchor="start" transform="translate(0, #{y})">|,
      ~s|<text x="2" dy="-0.32em" alignment-baseline="baseline">#{text}</text>|,
      "</g>"
    ]
  end

  defp get_svg_bars(%GanttChart{dataset: dataset, task_col: task_col, category_col: cat_col, interval_cols: {start_col, end_col}} = plot) do
    task_col_index = Dataset.column_index(dataset, task_col)
    cat_col_index = Dataset.column_index(dataset, cat_col)
    start_col_index = Dataset.column_index(dataset, start_col)
    end_col_index = Dataset.column_index(dataset, end_col)

    dataset.data
    |> Enum.map(fn row -> get_svg_bar(row, plot, task_col_index, cat_col_index, start_col_index, end_col_index) end)
  end

  defp get_svg_bar(row, %GanttChart{task_scale: task_scale, time_scale: time_scale, category_scale: cat_scale}=plot, task_col_index, cat_col_index, start_col_index, end_col_index) do
    task_data = Dataset.value(row, task_col_index)
    cat_data = Dataset.value(row, cat_col_index)
    start_time = Dataset.value(row, start_col_index)
    end_time = Dataset.value(row, end_col_index)
    title = ~s|#{task_data}: #{start_time} -> #{end_time}|

    {task_band_min, task_band_max} = OrdinalScale.get_band(task_scale, task_data)
    fill = CategoryColourScale.colour_for_value(cat_scale, cat_data)
    start_x = time_scale.domain_to_range_fn.(start_time)
    end_x = time_scale.domain_to_range_fn.(end_time)
    width = end_x - start_x
    height = abs(task_band_max - task_band_min)

    event_handler = get_bar_event_handler(row, plot, cat_data, task_data)

    [~s|<rect x="#{start_x}" y="#{task_band_min}" width="#{width}" height="#{height}" #{event_handler}|,
    ~s| style="fill: ##{fill};" >|,
    "<title>", title , "</title>",
    "</rect>",
    get_svg_bar_label(plot, {start_x, end_x}, task_data, {task_band_min, task_band_max})]
  end

  defp get_svg_bar_label(%GanttChart{show_task_labels: false}, _, _, _), do: ""
  defp get_svg_bar_label(_plot, {bar_start, bar_end}=bar, label, band) do
    text_y = midpoint(band)
    width = width(bar)

    {text_x, class, anchor} = case width < 50 do
      true -> {bar_end + 2, "exc-barlabel-out", "start"}
      _ -> {bar_start + 5, "exc-barlabel-in", "start"}
    end
    ~s|<text x="#{text_x}" y="#{text_y}" text-anchor="#{anchor}" class="#{class}" dominant-baseline="central">#{label}</text>|
  end

  defp get_bar_event_handler(_row, %GanttChart{phx_event_handler: phx_event_handler, id_col: ""}, category, task) when is_binary(phx_event_handler) and phx_event_handler != "" do
      ~s| phx-value-category="#{category}" phx-value-task="#{task}" phx-click="#{phx_event_handler}"|
  end
  defp get_bar_event_handler(row, %GanttChart{phx_event_handler: phx_event_handler, id_col: id_col, dataset: dataset}, _category, _task) when is_binary(phx_event_handler) and phx_event_handler != "" do
    id_col_index = Dataset.column_index(dataset, id_col)
    id = Dataset.value(row, id_col_index)
    ~s| phx-value-id="#{id}" phx-click="#{phx_event_handler}"|
  end
  defp get_bar_event_handler(_row, %GanttChart{}=_plot, _category, _task) do
    ""
  end

  defp get_category_band(%GanttChart{task_scale: task_scale, dataset: dataset}=plot, category) do
    task_col_index = Dataset.column_index(dataset, plot.task_col)
    cat_col_index = Dataset.column_index(dataset, plot.category_col)

    Enum.reduce(dataset.data, {nil, nil}, fn row, {min, max}=acc ->
      task = Dataset.value(row, task_col_index)
      cat = Dataset.value(row, cat_col_index)
      case cat == category do
        false -> {min, max}
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
