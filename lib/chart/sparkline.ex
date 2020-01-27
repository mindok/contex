defmodule Contex.Sparkline do
  alias __MODULE__
  alias Contex.{ContinuousLinearScale, Scale}

  defstruct [:data, :extents, :length, :spot_radius, :spot_colour,
      :line_width, :line_colour, :fill_colour, :y_transform,
      :height, :width]

  def new(data) when is_list(data) do
    %Sparkline{data: data, extents: ContinuousLinearScale.extents(data), length: length(data)}
      |> set_default_style
  end

  #TODO: Really need some validation...
  def colours(%Sparkline{} = sparkline,  fill, line) do
    %{sparkline | fill_colour: fill, line_colour: line}
  end

  defp set_default_style(%Sparkline{} = sparkline) do
    %{sparkline | spot_radius: 2, spot_colour: "red", line_width: 1,
        line_colour: "rgba(0, 200, 50, 0.7)", fill_colour: "rgba(0, 200, 50, 0.2)",
        height: 20, width: 100}
  end

  def draw(%Sparkline{height: height, width: width, line_width: line_width} = sparkline) do
    vb_width = sparkline.length + 1
    height = height + (2 * line_width)
    {min, max} = sparkline.extents
    vb_height = max - min
    scale = ContinuousLinearScale.new() |> ContinuousLinearScale.domain(sparkline.data) |> Scale.set_range(height, 0)
    sparkline = %{sparkline | y_transform: scale.domain_to_range_fn}

    output =
    ~s"""
       <svg height="#{height}" width="#{width}" viewBox="0 #{min - line_width} #{vb_width} #{vb_height}" preserveAspectRatio="none" role="img">
        <path d="#{get_closed_path(sparkline)}" #{get_fill_style(sparkline)}></path>
        <path d="#{get_path(sparkline)}" #{get_line_style(sparkline)}></path>
      </svg>
    """

    {:safe, [output]}
  end

  defp get_line_style(%Sparkline{line_colour: line_colour, line_width: line_width}) do
    ~s|stroke="#{line_colour}" stroke-width="#{line_width}" fill="none" vector-effect="non-scaling-stroke"|
  end

  defp get_fill_style(%Sparkline{fill_colour: fill_colour}) do
    ~s|stroke="none" fill="#{fill_colour}"|
  end

  defp get_closed_path(%Sparkline{extents: {min, max}} = sparkline) do
    height = max - min

    # Same as the open path, except we drop down, run back to height,height (aka 0,0) and close it...
    open_path = get_path(sparkline)
    [open_path, "V #{height} L 0 #{height} Z"]
  end

  # This is the IO List approach
  defp get_path(%Sparkline{y_transform: transform_func} = sparkline) do
    last_item = Enum.count(sparkline.data) - 1
    ["M", sparkline.data
         |> Enum.map(transform_func)
         |> Enum.with_index()
         |> Enum.map(fn {value, i} ->
            case i < last_item do
              true -> "#{i} #{value} L "
              _ -> "#{i} #{value}"
            end
          end)
    ]
  end

end

