defprotocol Contex.PlotContent do
  @moduledoc """
  Defines what a charting component needs to implement to be rendered within a `Contex.Plot`
  """

  @doc """
  Generates svg as a string or improper list of strings *without* the SVG containing element.
  """
  def to_svg(plot, options)

  @doc """
  Generates svg content for a legend appropriate for the plot content.
  """
  def get_svg_legend(plot)

  @doc """
  Sets the size for the plot content. This is called after the main layout and margin calculations
  are performed by the container plot.
  """
  def set_size(plot, width, height)
end

defmodule Contex.Plot do
  @moduledoc """
  Manages the layout of various plot elements, including titles, axis labels, legends etc and calculates
  appropriate margins depending on the options set.
  """
  import Contex.SVG
  alias __MODULE__
  alias Contex.{Dataset, PlotContent}

  defstruct [
    :title,
    :subtitle,
    :x_label,
    :y_label,
    :height,
    :width,
    :plot_content,
    :margins,
    :plot_options
  ]

  @type t() :: %__MODULE__{}
  @type plot_text() :: String.t() | nil
  @type row() :: list() | tuple()

  @default_plot_options [
    show_x_axis: true,
    show_y_axis: true,
    legend_setting: :legend_none
  ]

  @default_padding 10
  @top_title_margin 20
  @top_subtitle_margin 15
  @y_axis_margin 20
  @y_axis_tick_labels 70
  @legend_width 100
  @x_axis_margin 20
  @x_axis_tick_labels 70

  @doc """
  Creates a new plot with specified dataset and plot type. Other plot attributes can be set via a
  keyword list of options.
  """
  @spec new(Contex.Dataset.t(), module(), integer(), integer(), keyword()) :: Contex.Plot.t()
  def new(%Dataset{} = dataset, type, width, height, attrs \\ []) do
    # TODO
    # Seems like should just add new/3 to PlotContent protocol, but my efforts to do this failed.
    plot_content = apply(type, :new, [dataset, attrs])

    attributes =
      Keyword.merge(@default_plot_options, attrs)
      |> parse_attributes()

    %Plot{
      title: attributes.title,
      subtitle: attributes.subtitle,
      x_label: attributes.x_label,
      y_label: attributes.y_label,
      width: width,
      height: height,
      plot_content: plot_content,
      plot_options: attributes.plot_options
    }
    |> calculate_margins()
  end

  @doc """
  Creates a new plot with specified plot content.
  """
  @spec new(integer(), integer(), Contex.PlotContent.t()) :: Contex.Plot.t()
  def new(width, height, plot_content) do
    plot_options = %{show_x_axis: true, show_y_axis: true, legend_setting: :legend_none}

    %Plot{plot_content: plot_content, width: width, height: height, plot_options: plot_options}
    |> calculate_margins()
  end

  @doc """
  Replaces the plot dataset and updates the plot content. Accepts list of lists/tuples
  representing the new data and a list of strings with new headers.
  """
  @spec dataset(Contex.Plot.t(), list(row()), list(String.t())) :: Contex.Plot.t()
  def dataset(%Plot{} = plot, data, headers) do
    dataset = Dataset.new(data, headers)
    plot_content = apply(plot.plot_content.__struct__, :new, [dataset])
    %{plot | plot_content: plot_content}
  end

  @doc """
  Replaces the plot dataset and updates the plot content. Accepts a dataset or a list of lists/tuples
  representing the new data. The plot's dataset's original headers are preserved.
  """
  @spec dataset(Contex.Plot.t(), Contex.Dataset.t() | list(row())) :: Contex.Plot.t()
  def dataset(%Plot{} = plot, %Dataset{} = dataset) do
    plot_content = apply(plot.plot_content.__struct__, :new, [dataset])
    %{plot | plot_content: plot_content}
  end

  def dataset(%Plot{} = plot, data) do
    dataset =
      case plot.plot_content.dataset.headers do
        nil ->
          Dataset.new(data)

        headers ->
          Dataset.new(data, headers)
      end

    plot_content = apply(plot.plot_content.__struct__, :new, [dataset])
    %{plot | plot_content: plot_content}
  end

  @doc """
  Updates attributes for the plot. Takes a keyword list of attributes, which can include both "plot options"
  items passed individually as well as `:title`, `:subtitle`, `:x_label` and `:y_label`.
  """
  @spec attributes(Contex.Plot.t(), keyword()) :: Contex.Plot.t()
  def attributes(%Plot{} = plot, attrs) do
    attributes_map = Enum.into(attrs, %{})

    plot_options =
      Map.merge(
        plot.plot_options,
        Map.take(attributes_map, [:show_x_axis, :show_y_axis, :legend_setting])
      )

    plot
    |> Map.merge(
      Map.take(attributes_map, [:title, :subtitle, :x_label, :y_label, :width, :height])
    )
    |> Map.put(:plot_options, plot_options)
    |> calculate_margins()
  end

  @doc """
  Updates plot options for the plot.
  """
  def plot_options(%Plot{} = plot, new_plot_options) do
    existing_plot_options = plot.plot_options

    %{plot | plot_options: Map.merge(existing_plot_options, new_plot_options)}
    |> calculate_margins()
  end

  @doc """
  Sets the title and sub-title for the plot. Empty string or nil will remove the
  title or sub-title
  """
  @spec titles(Contex.Plot.t(), plot_text(), plot_text()) :: Contex.Plot.t()
  def titles(%Plot{} = plot, title, subtitle) do
    Plot.attributes(plot, title: title, subtitle: subtitle)
  end

  @doc """
  Sets the x-axis & y-axis labels for the plot. Empty string or nil will remove them.
  """
  @spec axis_labels(Contex.Plot.t(), plot_text(), plot_text()) :: Contex.Plot.t()
  def axis_labels(%Plot{} = plot, x_label, y_label) do
    Plot.attributes(plot, x_label: x_label, y_label: y_label)
  end

  @doc """
  Updates the size for the plot
  """
  @spec size(Contex.Plot.t(), integer(), integer()) :: Contex.Plot.t()
  def size(%Plot{} = plot, width, height) do
    Plot.attributes(plot, width: width, height: height)
  end

  @doc """
  Generates SVG output marked as safe for the configured plot.
  """
  def to_svg(%Plot{width: width, height: height, plot_content: plot_content} = plot) do
    %{left: left, right: right, top: top, bottom: bottom} = plot.margins
    content_height = height - (top + bottom)
    content_width = width - (left + right)

    # TODO: Legend calcs need to be redone if it can be displayed at the top
    legend_left = left + content_width + @default_padding
    legend_top = top + @default_padding

    plot_content = PlotContent.set_size(plot_content, content_width, content_height)

    output = [
      ~s|<svg class="chart" viewBox="0 0 #{width} #{height}"  role="img">|,
      get_titles_svg(plot, content_width),
      get_axis_labels_svg(plot, content_width, content_height),
      ~s|<g transform="translate(#{left},#{top})">|,
      PlotContent.to_svg(plot_content, plot.plot_options),
      "</g>",
      get_svg_legend(plot_content, legend_left, legend_top, plot.plot_options),
      "</svg>"
    ]

    {:safe, output}
  end

  defp get_svg_legend(plot_content, legend_left, legend_top, %{legend_setting: :legend_right}) do
    [
      ~s|<g transform="translate(#{legend_left}, #{legend_top})">|,
      PlotContent.get_svg_legend(plot_content),
      "</g>"
    ]
  end

  defp get_svg_legend(_plot_content, _legend_left, _legend_top, _opts), do: ""

  defp get_titles_svg(
         %Plot{title: title, subtitle: subtitle, margins: margins} = _plot,
         content_width
       )
       when is_binary(title) or is_binary(subtitle) do
    centre = margins.left + content_width / 2.0
    title_y = @top_title_margin

    title_svg =
      case is_non_empty_string(title) do
        true ->
          text(centre, title_y, title, class: "exc-title", text_anchor: "middle")

        _ ->
          ""
      end

    subtitle_y =
      case is_non_empty_string(title) do
        true -> @top_subtitle_margin + @top_title_margin
        _ -> @top_subtitle_margin
      end

    subtitle_svg =
      case is_non_empty_string(subtitle) do
        true ->
          text(centre, subtitle_y, subtitle, class: "exc-subtitle", text_anchor: "middle")

        _ ->
          ""
      end

    [title_svg, subtitle_svg]
  end

  defp get_titles_svg(_, _), do: ""

  defp get_axis_labels_svg(
         %Plot{x_label: x_label, y_label: y_label, margins: margins} = _plot,
         content_width,
         content_height
       )
       when is_binary(x_label) or is_binary(y_label) do
    x_label_x = margins.left + content_width / 2.0
    x_label_y = margins.top + content_height + @x_axis_tick_labels

    # -90 rotation screws with coordinates
    y_label_x = -1.0 * (margins.top + content_height / 2.0)
    y_label_y = @y_axis_margin

    x_label_svg =
      case is_non_empty_string(x_label) do
        true ->
          text(x_label_x, x_label_y, x_label, class: "exc-subtitle", text_anchor: "middle")

        _ ->
          ""
      end

    y_label_svg =
      case is_non_empty_string(y_label) do
        true ->
          text(y_label_x, y_label_y, y_label,
            class: "exc-subtitle",
            text_anchor: "middle",
            transform: "rotate(-90)"
          )

        false ->
          ""
      end

    [x_label_svg, y_label_svg]
  end

  defp get_axis_labels_svg(_, _, _), do: ""

  defp parse_attributes(attrs) do
    %{
      title: Keyword.get(attrs, :title),
      subtitle: Keyword.get(attrs, :subtitle),
      x_label: Keyword.get(attrs, :x_label),
      y_label: Keyword.get(attrs, :y_label),
      plot_options:
        Enum.into(Keyword.take(attrs, [:show_x_axis, :show_y_axis, :legend_setting]), %{})
    }
  end

  defp calculate_margins(%Plot{} = plot) do
    left = Map.get(plot.plot_options, :left_margin, calculate_left_margin(plot))
    top = Map.get(plot.plot_options, :top_margin, calculate_top_margin(plot))
    right = Map.get(plot.plot_options, :right_margin, calculate_right_margin(plot))
    bottom = Map.get(plot.plot_options, :bottom_margin, calculate_bottom_margin(plot))

    margins = %{left: left, top: top, right: right, bottom: bottom}

    %{plot | margins: margins}
  end

  defp calculate_left_margin(%Plot{} = plot) do
    margin = 0
    margin = margin + if plot.plot_options.show_y_axis, do: @y_axis_tick_labels, else: 0
    margin = margin + if is_non_empty_string(plot.y_label), do: @y_axis_margin, else: 0

    margin
  end

  defp calculate_right_margin(%Plot{} = plot) do
    margin = @default_padding

    margin =
      margin + if plot.plot_options.legend_setting == :legend_right, do: @legend_width, else: 0

    margin
  end

  defp calculate_bottom_margin(%Plot{} = plot) do
    margin = 0
    margin = margin + if plot.plot_options.show_x_axis, do: @x_axis_tick_labels, else: 0
    margin = margin + if is_non_empty_string(plot.x_label), do: @x_axis_margin, else: 0

    margin
  end

  defp calculate_top_margin(%Plot{} = plot) do
    margin = @default_padding

    margin =
      margin +
        if is_non_empty_string(plot.title), do: @top_title_margin + @default_padding, else: 0

    margin = margin + if is_non_empty_string(plot.subtitle), do: @top_subtitle_margin, else: 0

    margin
  end

  defp is_non_empty_string(val) when is_nil(val), do: false
  defp is_non_empty_string(val) when val == "", do: false
  defp is_non_empty_string(val) when is_binary(val), do: true
  defp is_non_empty_string(_), do: false
end

# TODO: Probably move to appropriate module files...
defimpl Contex.PlotContent, for: Contex.BarChart do
  def to_svg(plot, options), do: Contex.BarChart.to_svg(plot, options)
  def get_svg_legend(plot), do: Contex.BarChart.get_svg_legend(plot)
  def set_size(plot, width, height), do: Contex.BarChart.set_size(plot, width, height)
end

defimpl Contex.PlotContent, for: Contex.PointPlot do
  def to_svg(plot, _options), do: Contex.PointPlot.to_svg(plot)
  def get_svg_legend(plot), do: Contex.PointPlot.get_svg_legend(plot)
  def set_size(plot, width, height), do: Contex.PointPlot.set_size(plot, width, height)
end

defimpl Contex.PlotContent, for: Contex.GanttChart do
  def to_svg(plot, options), do: Contex.GanttChart.to_svg(plot, options)
  # Contex.PointPlot.get_legend_svg(plot)
  def get_svg_legend(_plot), do: ""
  def set_size(plot, width, height), do: Contex.GanttChart.set_size(plot, width, height)
end
