defmodule Contex.BarPlot do

  alias __MODULE__
  alias Contex.{Scale, ContinuousScale, OrdinalScale}
  alias Contex.CategoryColourScale
  alias Contex.Dataset
  alias Contex.Axis
  alias Contex.Utils

  defstruct [:data, :width, :height, :category_col, :value_cols, :category_scale, :value_scale,
        :type, :orientation, :padding, :data_labels, :colour_palette, :series_fill_colours, :custom_value_formatter,
        :phx_event_handler, :select_item, :value_range]

  #@colours ["DF691A", "e83e8c", "d9534f", "f0ad4e", "6610f2", "f0ad4e", "5cb85c", "6f42c1", "20c99", "5bc0de"]
  #Warm colours - see https://learnui.design/tools/data-color-picker.html#single
  #@colours ["d40810", "e76241", "f69877", "ffcab4", "ffeac4", "fffae4"]



  def new(%Dataset{} = data, orientation \\ :vertical) do
    %BarPlot{data: data, width: 100, height: 100, orientation: orientation, value_range: nil}
    |> defaults()
  end

  def defaults(%BarPlot{} = plot) do
    cat_col_index = 0
    val_col_index = 1

    plot = %{plot | padding: 2, type: :stacked, colour_palette: :default}

    cat_col_name = Dataset.column_name(plot.data, cat_col_index)
    val_col_names = [Dataset.column_name(plot.data, val_col_index)]

    plot
    |> set_cat_col_name(cat_col_name)
    |> set_val_col_names(val_col_names)
    |> data_labels(true)
  end

  def data_labels(%BarPlot{} = plot, data_labels) do
    %{plot | data_labels: data_labels}
  end

  def type(%BarPlot{} = plot, type) do
    %{plot | type: type}
    |> set_val_col_names(plot.value_cols)
  end

  def orientation(%BarPlot{} = plot, orientation) do
    %{plot | orientation: orientation}
  end

  def force_value_range(%BarPlot{} = plot, {min, max}=value_range) when is_number(min) and is_number(max) do
    %{plot | value_range: value_range}
    |> set_val_col_names(plot.value_cols)
  end

  def set_size(%BarPlot{} = plot, width, height) do
    # We pretend to set the value and category columns to force a recalculation of scales - may be expensive.
    # We only really need to set the range, not recalculate the domain
    %{plot | width: width, height: height}
    |> set_val_col_names(plot.value_cols)
    |> set_cat_col_name(plot.category_col)
  end

  def padding(%BarPlot{category_scale: %OrdinalScale{}=cat_scale} = plot, padding) when is_number(padding) do
    cat_scale = OrdinalScale.padding(cat_scale, padding)
    %{plot | padding: padding, category_scale: cat_scale}
  end
  def padding(%BarPlot{} = plot, padding) when is_number(padding) do
    %{plot | padding: padding}
  end

  def colours(plot, colour_palette) when is_list(colour_palette) do
    %{plot | colour_palette: colour_palette}
    |> set_val_col_names(plot.value_cols)
  end
  def colours(plot, colour_palette) when is_atom(colour_palette) do
    %{plot | colour_palette: colour_palette}
    |> set_val_col_names(plot.value_cols)
  end
  def colours(plot, _) do
    %{plot | colour_palette: :default}
    |> set_val_col_names(plot.value_cols)
  end


  def event_handler(%BarPlot{}=plot, event_handler) do
    %{plot | phx_event_handler: event_handler}
  end

  def select_item(%BarPlot{}=plot, select_item) do
    %{plot | select_item: select_item}
  end

  def custom_value_formatter(%BarPlot{}=plot, custom_value_formatter) when is_function(custom_value_formatter) or custom_value_formatter==nil do
    %{plot | custom_value_formatter: custom_value_formatter}
  end

  def to_svg(%BarPlot{category_scale: category_scale, value_scale: value_scale, orientation: orientation} = plot, options) do
    options = refine_options(options, orientation)

    category_axis = get_category_axis(category_scale, orientation, plot)
    value_scale = %{value_scale | custom_tick_formatter: plot.custom_value_formatter}
    value_axis = get_value_axis(value_scale, orientation, plot)
    plot = %{plot | value_scale: value_scale}

    cat_axis_svg = if options.show_cat_axis do Axis.to_svg(category_axis) else "" end
    val_axis_svg = if options.show_val_axis do Axis.to_svg(value_axis) else "" end

    [
      cat_axis_svg,
      val_axis_svg,
      "<g>",
      get_svg_bars(plot),
      "</g>"
    ]
  end

  defp refine_options(options, :horizontal), do: options |> Map.put(:show_cat_axis, options.show_y_axis) |> Map.put(:show_val_axis, options.show_x_axis)
  defp refine_options(options, _), do: options |> Map.put(:show_cat_axis, options.show_x_axis) |> Map.put(:show_val_axis, options.show_y_axis)

  defp get_category_axis(category_scale, :horizontal, plot) do
    Axis.new_left_axis(category_scale) |> Axis.set_offset(plot.width)
  end
  defp get_category_axis(category_scale, _, plot) do
    category_axis =  Axis.new_bottom_axis(category_scale) |> Axis.set_offset(plot.height)

    #TODO: Move into defaults and options
    category_axis = case length(Scale.ticks_range(category_scale)) > 8 do
      true -> %{category_axis | rotation: 45}
      _ -> category_axis
    end

    category_axis
  end

  defp get_value_axis(value_scale, :horizontal, plot), do: Axis.new_bottom_axis(value_scale) |> Axis.set_offset(plot.height)
  defp get_value_axis(value_scale, _, plot), do: Axis.new_left_axis(value_scale) |> Axis.set_offset(plot.width)

  def get_svg_legend(%BarPlot{series_fill_colours: scale, orientation: :vertical, type: :stacked}) do
    Contex.Legend.to_svg(scale, true)
  end
  def get_svg_legend(%BarPlot{series_fill_colours: scale}) do
    Contex.Legend.to_svg(scale)
  end

  defp get_svg_bars(%BarPlot{data: dataset} = plot) do
    cat_col_index = Dataset.column_index(dataset, plot.category_col)
    val_col_indices = Enum.map(plot.value_cols, fn col -> Dataset.column_index(dataset, col) end)

    series_fill_colours = plot.series_fill_colours
    fills = Enum.map(plot.value_cols, fn column -> CategoryColourScale.colour_for_value(series_fill_colours, column) end)

    dataset.data
    |> Enum.map(fn row -> get_svg_bar(row, plot, cat_col_index, val_col_indices, fills) end)
  end

  defp get_svg_bar(row, %BarPlot{category_scale: category_scale, value_scale: value_scale}=plot, cat_col_index, val_col_indices, fills) do
    cat_data = Dataset.value(row, cat_col_index)
    series_values = Enum.map(val_col_indices, fn index -> Dataset.value(row, index) end)

    cat_band = OrdinalScale.get_band(category_scale, cat_data)
    bar_values = prepare_bar_values(series_values, value_scale, plot.type)
    labels = Enum.map(series_values, fn val -> Scale.get_formatted_tick(value_scale, val) end)
    event_handlers = get_bar_event_handlers(plot, cat_data, series_values)
    opacities = get_bar_opacities(plot, cat_data)

    get_svg_bar_rects(cat_band, bar_values, labels, plot, fills, event_handlers, opacities)
  end

  defp get_bar_event_handlers(%BarPlot{phx_event_handler: phx_event_handler, value_cols: value_cols}, category, series_values) when is_binary(phx_event_handler) and phx_event_handler != "" do
    Enum.zip(value_cols, series_values)
    |> Enum.map(fn {col, value} ->
      ~s| phx-value-category="#{category}" phx-value-series="#{col}" phx-value-value="#{value}" phx-click="#{phx_event_handler}"|
    end)
  end
  defp get_bar_event_handlers(%BarPlot{value_cols: value_cols}, _, _), do: Enum.map(value_cols, fn _ -> "" end)

  defp get_bar_opacities(%BarPlot{select_item: %{category: selected_category, series: _selected_series}, value_cols: value_cols}, category) when selected_category != category do
    Enum.map(value_cols, fn _ -> ~s|fill-opacity="0.3"| end)
  end
  defp get_bar_opacities(%BarPlot{select_item: %{category: _selected_category, series: selected_series}, value_cols: value_cols}, _category) do
    Enum.map(value_cols, fn col ->
      case col == selected_series do
        true -> ""
        _ -> ~s|fill-opacity="0.3"|
      end
    end)
  end
  defp get_bar_opacities(%BarPlot{value_cols: value_cols}, _), do: Enum.map(value_cols, fn _ -> "" end)

  # Transforms the raw value for each series into a list of range tuples the bar has to cover, scaled to the display area
  defp prepare_bar_values(series_values, scale, :stacked) do
    {results, _last_val} = Enum.reduce(series_values, {[], 0}, fn data_val, {points, last_val} ->
      end_val = data_val + last_val
      new = {scale.domain_to_range_fn.(last_val), scale.domain_to_range_fn.(end_val)}
      {[new | points], end_val}
    end)
    Enum.reverse(results)
  end
  defp prepare_bar_values(series_values, scale, :grouped) do
    {scale_min, _} = Scale.get_range(scale)

    results = Enum.reduce(series_values, [], fn data_val, points ->
      range_val = scale.domain_to_range_fn.(data_val)
      [{scale_min, range_val} | points]
    end)

    Enum.reverse(results)
  end

  defp get_svg_bar_rects({cat_band_min, cat_band_max}=cat_band, bar_values, labels, plot, fills, event_handlers, opacities) when is_number(cat_band_min) and is_number(cat_band_max) do
    count = length(bar_values)
    indices = 0..(count-1)

    adjusted_bands = Enum.map(indices, fn index -> adjust_cat_band(cat_band, index, count, plot.type, plot.orientation) end)

    rects = Enum.zip([bar_values, fills, labels, adjusted_bands, event_handlers, opacities])
    |> Enum.map(fn {bar_value, fill, label, adjusted_band, event_handler, opacity} ->
      {x, y, width, height} = get_bar_rect_coords(plot.orientation, adjusted_band, bar_value)

      [~s|<rect x="#{x}" y="#{y}" width="#{width}" height="#{height}" #{event_handler}|,
      ~s| style="fill: ##{fill};" #{opacity}>|,
      ~s|<title>#{label}</title>|,
      "</rect>"]
    end)

    texts = case (count < 4) and plot.data_labels do
      false -> []
      _ ->
        Enum.zip([bar_values, labels, adjusted_bands])
      |> Enum.map(fn {bar_value, label, adjusted_band} ->
        get_svg_bar_label(plot.orientation, bar_value, label, adjusted_band, plot)
       end)
    end

    [rects, texts] #TODO: Get nicer text with big stacks - maybe limit to two series
  end
  defp get_svg_bar_rects(_x, _y, _label, _plot, _fill, _event_handlers, _opacities), do: ""

  defp adjust_cat_band(cat_band, _index, _count, :stacked, _), do: cat_band
  defp adjust_cat_band({cat_band_start, cat_band_end}, index, count, :grouped, :vertical) do
    interval = (cat_band_end - cat_band_start) / count
    {cat_band_start + (index * interval), cat_band_start + ((index + 1) * interval)}
  end
  defp adjust_cat_band({cat_band_start, cat_band_end}, index, count, :grouped, :horizontal) do
    interval = (cat_band_end - cat_band_start) / count
    # Flip index so that first series is at top of group
    index = (count - index) - 1
    {cat_band_start + (index * interval), cat_band_start + ((index + 1) * interval)}
  end

  defp get_bar_rect_coords(:horizontal, {cat_band_min, cat_band_max}, {bar_start, bar_end}) do
    x = bar_start
    height = abs(cat_band_max - cat_band_min)
    width = abs(bar_end - bar_start)
    y = cat_band_max

    {x, y, width, height}
  end
  defp get_bar_rect_coords(:vertical, {cat_band_min, cat_band_max}, {bar_start, bar_end}) do
    x = cat_band_min
    width = abs(cat_band_max - cat_band_min)
    height = abs(bar_start - bar_end)
    y = bar_end

    {x, y, width, height}
  end

  defp get_svg_bar_label(:horizontal, {_, bar_end}=bar, label, cat_band, _plot) do
    text_y = midpoint(cat_band)
    width = width(bar)

    {text_x, class, anchor} = case width < 50 do
      true -> {bar_end + 2, "exc-barlabel-out", "start"}
      _ -> {midpoint(bar), "exc-barlabel-in", "middle"}
    end
    ~s|<text x="#{text_x}" y="#{text_y}" text-anchor="#{anchor}" class="#{class}" dominant-baseline="central">#{label}</text>|
  end

  defp get_svg_bar_label(_, {bar_start, _}=bar, label, cat_band, _plot) do
    text_x = midpoint(cat_band)

    {text_y, class} = case width(bar) > 20 do
      true -> {midpoint(bar), "exc-barlabel-in"}
      _ -> {bar_start - 10, "exc-barlabel-out"}
    end

    ~s|<text x="#{text_x}" y="#{text_y}" text-anchor="middle" class="#{class}">#{label}</text>|
  end

  def set_cat_col_name(%BarPlot{padding: padding} = plot, cat_col_name) do
    categories = Dataset.unique_values(plot.data, cat_col_name)
    {r_min, r_max} = get_range(:category, plot)
    cat_scale = OrdinalScale.new(categories) |> Scale.set_range(r_min, r_max) |> OrdinalScale.padding(padding)

    %{plot | category_col: cat_col_name, category_scale: cat_scale}
  end

  def set_val_col_names(%BarPlot{} = plot, val_col_names) when is_list(val_col_names) do
    {min, max} =
      get_overall_value_domain(plot, plot.data, val_col_names, plot.type)
      |> fixup_val_range()

    {r_start, r_end} = get_range(:value, plot)

    val_scale = ContinuousScale.new_linear() |> ContinuousScale.domain(min, max) |> Scale.set_range(r_start, r_end)

    series_fill_colours
      = CategoryColourScale.new(val_col_names)
      |> CategoryColourScale.set_palette(plot.colour_palette)

    %{plot | value_cols: val_col_names, value_scale: val_scale, series_fill_colours: series_fill_colours}
  end

  def set_val_col_names(%BarPlot{} = plot, _), do: plot

  defp get_range(:category, %BarPlot{orientation: :horizontal}=plot), do: {plot.height, 0}
  defp get_range(:category, plot), do: {0, plot.width}

  defp get_range(:value,  %BarPlot{orientation: :horizontal}=plot), do: {0, plot.width}
  defp get_range(:value, plot), do: {plot.height, 0}

  defp get_overall_value_domain(%BarPlot{value_range: {min, max}}, _, _, _), do: {min, max}

  defp get_overall_value_domain(_plot, data, col_names, :stacked) do
    {_, max} = Dataset.combined_column_extents(data, col_names)
    {0, max}
  end

  defp get_overall_value_domain(_plot, data, col_names, :grouped) do
    combiner = fn {min1, max1}, {min2, max2} -> {Utils.safe_min(min1, min2), Utils.safe_max(max1, max2)} end

    Enum.reduce(col_names, {nil, nil}, fn col, acc_extents ->
          inner_extents = Dataset.column_extents(data, col)
          combiner.(acc_extents, inner_extents)
        end )
  end

  defp fixup_val_range({min, max}) when min == max and max > 0, do: {0, max}
  defp fixup_val_range({min, max}) when min == max and max < 0, do: {max, 0}
  defp fixup_val_range({min, max}), do: {min, max}

  defp midpoint({a, b}), do: (a + b) / 2.0
  defp width({a, b}), do: abs(a - b)

end
