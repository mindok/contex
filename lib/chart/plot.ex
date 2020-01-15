defprotocol Contex.PlotContent do
  def to_svg(plot, options)
  def get_svg_legend(plot)
  def set_size(plot, width, height)
end


defmodule Contex.Plot do
  alias __MODULE__
  alias Contex.PlotContent

  defstruct [:title, :subtitle, :x_label, :y_label, :height, :width, :plot_content, :margins, :plot_options]

  @default_padding 10
  @top_title_margin 20
  @top_subtitle_margin 15
  @y_axis_margin 20
  @y_axis_tick_labels 70
  @legend_width 100
  @x_axis_margin 20
  @x_axis_tick_labels 70

  def new(width, height, plot_content) do
    plot_options = %{show_x_axis: true, show_y_axis: true, legend_setting: :legend_none }
    %Plot{plot_content: plot_content, width: width, height: height, plot_options: plot_options}
    |> calculate_margins
  end

  #TODO: Allow overriding of margins
  def plot_options(%Plot{}=plot, new_plot_options) do
    existing_plot_options = plot.plot_options
    %{plot | plot_options: Map.merge(existing_plot_options, new_plot_options)}
    |> calculate_margins
  end

  def titles(%Plot{}=plot, title, subtitle) do
    %{plot | title: title, subtitle: subtitle}
    |> calculate_margins
  end

  def axis_labels(%Plot{}=plot, x_label, y_label) do
    %{plot | x_label: x_label, y_label: y_label}
    |> calculate_margins
  end

  def size(%Plot{}=plot, width, height) do
    %{plot | width: width, height: height}
    |> calculate_margins
  end


  def to_svg(%Plot{width: width, height: height, plot_content: plot_content}=plot) do
    %{left: left, right: right, top: top, bottom: bottom} = plot.margins
    content_height = height - (top + bottom)
    content_width = width - (left + right)

    # TODO: Legend calcs need to be redone if it can be displayed at the top
    legend_left = left + content_width + @default_padding
    legend_top = top + @default_padding

    plot_content = PlotContent.set_size(plot_content, content_width, content_height)

    output =
      [~s|<svg class="chart" viewBox="0 0 #{width} #{height}"  role="img">|,
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
    [~s|<g transform="translate(#{legend_left}, #{legend_top})">|,
      PlotContent.get_svg_legend(plot_content),
      "</g>"
    ]
  end
  defp get_svg_legend(_plot_content, _legend_left, _legend_top, _opts), do: ""

  defp get_titles_svg(%Plot{title: title, subtitle: subtitle, margins: margins}=_plot, content_width) when is_binary(title) or is_binary(subtitle) do
    centre = margins.left + (content_width / 2.0)
    title_y = @top_title_margin

    title_svg = case title do
      "" -> ""
      nil -> ""
      _ -> ~s|<text class="exc-title" x="#{centre}" y="#{title_y}" text-anchor="middle">#{title}</text>|
    end

    subtitle_y = case title do
      "" -> @top_subtitle_margin
      nil -> @top_subtitle_margin
      _ -> @top_subtitle_margin + @top_title_margin
    end

    subtitle_svg = case subtitle do
      "" -> ""
      nil -> ""
      _ -> ~s|<text class="exc-subtitle" x="#{centre}" y="#{subtitle_y}" text-anchor="middle">#{subtitle}</text>|
    end

    [title_svg, subtitle_svg]
  end
  defp get_titles_svg(_, _), do: ""

  defp get_axis_labels_svg(%Plot{x_label: x_label, y_label: y_label, margins: margins}=_plot, content_width, content_height) when is_binary(x_label) or is_binary(y_label) do
    x_label_x = margins.left + (content_width / 2.0)
    x_label_y = margins.top + content_height + @x_axis_tick_labels

    y_label_x = -1.0 * (margins.top + (content_height / 2.0)) # -90 rotation screws with coordinates
    y_label_y = @y_axis_margin

    x_label_svg = case x_label do
      "" -> ""
      nil -> ""
      _ -> ~s|<text class="exc-subtitle" x="#{x_label_x}" y="#{x_label_y}" text-anchor="middle">#{x_label}</text>|
    end

    y_label_svg = case y_label do
      "" -> ""
      nil -> ""
      _ -> ~s|<text transform="rotate(-90)" class="exc-subtitle" x="#{y_label_x}" y="#{y_label_y}" text-anchor="middle">#{y_label}</text>|
    end

    [x_label_svg, y_label_svg]
  end
  defp get_axis_labels_svg(_, _, _), do: ""

  defp calculate_margins(%Plot{}=plot) do
    left = calculate_left_margin(plot)
    top = calculate_top_margin(plot)
    right = calculate_right_margin(plot)
    bottom = calculate_bottom_margin(plot)

    margins = %{left: left, top: top, right: right, bottom: bottom}

    %{plot | margins: margins}
  end

  def calculate_left_margin(%Plot{}=plot) do
    margin = case plot.plot_options.show_y_axis do
      true -> @y_axis_tick_labels
      _ -> 0
    end

    margin = margin + case plot.y_label do
      nil -> 0
      "" -> 0
      _ -> @y_axis_margin
    end

    margin
  end

  def calculate_right_margin(%Plot{}=plot) do
    margin = @default_padding

    margin = margin + case plot.plot_options.legend_setting do
      :legend_right -> @legend_width
      _ -> 0
    end

    margin
  end

  def calculate_bottom_margin(%Plot{}=plot) do
    margin =     margin = case plot.plot_options.show_x_axis do
      true -> @x_axis_tick_labels
      _ -> 0
    end

    margin = margin + case plot.x_label do
      nil -> 0
      "" -> 0
      _ -> @x_axis_margin
    end

    margin
  end

  def calculate_top_margin(%Plot{}=plot) do
    margin = @default_padding
    margin = margin + case plot.title do
      nil -> 0
      "" -> 0
      _ -> @top_title_margin + @default_padding
    end

    margin = margin + case plot.subtitle do
      nil -> 0
      "" -> 0
      _ -> @top_subtitle_margin
    end

    margin
  end

end

#TODO: Probably move to appropriate module files...
defimpl Contex.PlotContent, for: Contex.BarPlot do
  def to_svg(plot, options), do: Contex.BarPlot.to_svg(plot, options)
  def get_svg_legend(plot), do: Contex.BarPlot.get_svg_legend(plot)
  def set_size(plot, width, height), do: Contex.BarPlot.set_size(plot, width, height)
end

defimpl Contex.PlotContent, for: Contex.PointPlot do
  def to_svg(plot, _options), do: Contex.PointPlot.to_svg(plot)
  def get_svg_legend(_plot), do: "" #Contex.PointPlot.get_legend_svg(plot)
  def set_size(plot, width, height), do: Contex.PointPlot.set_size(plot, width, height)
end

defimpl Contex.PlotContent, for: Contex.GanttChart do
  def to_svg(plot, options), do: Contex.GanttChart.to_svg(plot, options)
  def get_svg_legend(_plot), do: "" #Contex.PointPlot.get_legend_svg(plot)
  def set_size(plot, width, height), do: Contex.GanttChart.set_size(plot, width, height)
end
