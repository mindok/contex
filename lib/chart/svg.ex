defmodule Contex.SVG do
  @moduledoc """
  Convenience functions for generating SVG output
  """

  def text(x, y, content, opts \\ []) do
    attrs = opts_to_attrs(opts)

    [
      "<text ",
      ~s|x="#{x}" y="#{y}"|,
      attrs,
      ">",
      clean(content),
      "</text>"
    ]
  end

  def text(content, opts \\ []) do
    attrs = opts_to_attrs(opts)

    [
      "<text ",
      attrs,
      ">",
      clean(content),
      "</text>"
    ]
  end

  def title(content, opts \\ []) do
    attrs = opts_to_attrs(opts)

    [
      "<title ",
      attrs,
      ">",
      clean(content),
      "</title>"
    ]
  end

  def rect({_x1, _x2} = x_extents, {_y1, _y2} = y_extents, inner_content, opts \\ []) do
    width = width(x_extents)
    height = width(y_extents)
    y = min(y_extents)
    x = min(x_extents)

    attrs = opts_to_attrs(opts)

    [
      "<rect ",
      ~s|x="#{x}" y="#{y}" width="#{width}" height="#{height}"|,
      attrs,
      ">",
      inner_content,
      "</rect>"
    ]
  end

  def circle(x, y, radius, opts \\ []) do
    attrs = opts_to_attrs(opts)

    [
      "<circle ",
      ~s|cx="#{x}" cy="#{y}" r="#{radius}"|,
      attrs,
      "></circle>"
    ]
  end

  def line(points, smoothed, opts \\ []) do
    attrs = opts_to_attrs(opts)

    path = path(points, smoothed)

    [
      "<path d=\"",
      path,
      "\"",
      attrs,
      "></path>"
    ]
  end

  defp path([], _), do: ""

  defp path(points, false) do
    Enum.reduce(points, :first, fn {x, y}, acc ->
      coord = ~s|#{x} #{y}|

      case acc do
        :first -> ["M ", coord]
        _ -> [acc, " L " | coord]
      end
    end)
  end

  defp path(points, true) do
    # Use Catmull-Rom curve - see http://schepers.cc/getting-to-the-point
    # First point stays as-is. Subsequent points are draw using SVG cubic-spline
    # where control points are calculated as follows:
    # - Take the immediately prior data point, the data point itself and the next two into
    # an array of 4 points. Where this isn't possible (first & last) duplicate
    # Apply Cardinal Spline to Cubic Bezier conversion matrix (this is with tension = 0.0)
    #    0       1       0       0
    #  -1/6      1      1/6      0
    #    0      1/6      1     -1/6
    #    0       0       1       0
    # First control point is second result, second control point is third result, end point is last result

    initial_window = {nil, nil, nil, nil}

    {_, window, last_p, result} =
      Enum.reduce(points, {:first, initial_window, nil, ""}, fn p,
                                                                {step, window, last_p, result} ->
        case step do
          :first ->
            {:second, {p, p, p, p}, p, []}

          :second ->
            {:rest, bump_window(window, p), p, ["M ", coord(last_p)]}

          :rest ->
            window = bump_window(window, p)
            {cp1, cp2} = cardinal_spline_control_points(window)
            {:rest, window, p, [result, " C " | [coord(cp1), coord(cp2), coord(last_p)]]}
        end
      end)

    window = bump_window(window, last_p)
    {cp1, cp2} = cardinal_spline_control_points(window)

    [result, " C " | [coord(cp1), coord(cp2), coord(last_p)]]
  end

  defp bump_window({_p1, p2, p3, p4}, new_p), do: {p2, p3, p4, new_p}

  @spline_tension 0.3
  @factor (1.0 - @spline_tension) / 6.0
  defp cardinal_spline_control_points({{x1, y1}, {x2, y2}, {x3, y3}, {x4, y4}}) do
    cp1 = {x2 + @factor * (x3 - x1), y2 + @factor * (y3 - y1)}
    cp2 = {x3 + @factor * (x2 - x4), y3 + @factor * (y2 - y4)}

    {cp1, cp2}
  end

  defp coord({x, y}) do
    ~s| #{x} #{y}|
  end

  def opts_to_attrs(opts), do: opts_to_attrs(opts, [])

  defp opts_to_attrs([{_, nil} | t], attrs), do: opts_to_attrs(t, attrs)
  defp opts_to_attrs([{_, ""} | t], attrs), do: opts_to_attrs(t, attrs)

  defp opts_to_attrs([{:phx_click, val} | t], attrs),
    do: opts_to_attrs(t, [[" phx-click=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:phx_target, val} | t], attrs),
    do: opts_to_attrs(t, [[" phx-target=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:series, val} | t], attrs),
    do: opts_to_attrs(t, [[" phx-value-series=\"", "#{clean(val)}", "\""] | attrs])

  defp opts_to_attrs([{:category, val} | t], attrs),
    do: opts_to_attrs(t, [[" phx-value-category=\"", "#{clean(val)}", "\""] | attrs])

  defp opts_to_attrs([{:value, val} | t], attrs),
    do: opts_to_attrs(t, [[" phx-value-value=\"", "#{clean(val)}", "\""] | attrs])

  defp opts_to_attrs([{:id, val} | t], attrs),
    do: opts_to_attrs(t, [[" phx-value-id=\"", "#{val}", "\""] | attrs])

  defp opts_to_attrs([{:task, val} | t], attrs),
    do: opts_to_attrs(t, [[" phx-value-task=\"", "#{clean(val)}", "\""] | attrs])

  # TODO: This is going to break down with more complex styles
  defp opts_to_attrs([{:fill, val} | t], attrs),
    do: opts_to_attrs(t, [[" style=\"fill:#", val, ";\""] | attrs])

  defp opts_to_attrs([{:transparent, true} | t], attrs),
    do: opts_to_attrs(t, [[" fill=\"transparent\""] | attrs])

  defp opts_to_attrs([{:stroke, val} | t], attrs),
    do: opts_to_attrs(t, [[" stroke=\"#", val, "\""] | attrs])

  defp opts_to_attrs([{:stroke_width, val} | t], attrs),
    do: opts_to_attrs(t, [[" stroke-width=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:stroke_linejoin, val} | t], attrs),
    do: opts_to_attrs(t, [[" stroke-linejoin=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:opacity, val} | t], attrs),
    do: opts_to_attrs(t, [[" fill-opacity=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:class, val} | t], attrs),
    do: opts_to_attrs(t, [[" class=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:transform, val} | t], attrs),
    do: opts_to_attrs(t, [[" transform=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:text_anchor, val} | t], attrs),
    do: opts_to_attrs(t, [[" text-anchor=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:dominant_baseline, val} | t], attrs),
    do: opts_to_attrs(t, [[" dominant-baseline=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:alignment_baseline, val} | t], attrs),
    do: opts_to_attrs(t, [[" alignment-baseline=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:marker_start, val} | t], attrs),
    do: opts_to_attrs(t, [[" marker-start=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:marker_mid, val} | t], attrs),
    do: opts_to_attrs(t, [[" marker-mid=\"", val, "\""] | attrs])

  defp opts_to_attrs([{:marker_end, val} | t], attrs),
    do: opts_to_attrs(t, [[" marker-end=\"", val, "\""] | attrs])

  defp opts_to_attrs([{key, val} | t], attrs) when is_atom(key),
    do: opts_to_attrs(t, [[" ", Atom.to_string(key), "=\"", clean(val), "\""] | attrs])

  defp opts_to_attrs([{key, val} | t], attrs) when is_binary(key),
    do: opts_to_attrs(t, [[" ", key, "=\"", clean(val), "\""] | attrs])

  defp opts_to_attrs([], attrs), do: attrs

  defp width({a, b}), do: abs(a - b)
  defp min({a, b}), do: min(a, b)

  defp clean(s), do: Contex.SVG.Sanitize.basic_sanitize(s)
end
