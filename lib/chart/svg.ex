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

  def opts_to_attrs(opts), do: opts_to_attrs(opts, [])

  defp opts_to_attrs([{_, nil} | t], attrs), do: opts_to_attrs(t, attrs)
  defp opts_to_attrs([{_, ""} | t], attrs), do: opts_to_attrs(t, attrs)

  defp opts_to_attrs([{:phx_click, val} | t], attrs),
    do: opts_to_attrs(t, [[" phx-click=\"", val, "\""] | attrs])

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

  defp opts_to_attrs([{key, val} | t], attrs) when is_atom(key),
    do: opts_to_attrs(t, [[" ", Atom.to_string(key), "=\"", clean(val), "\""] | attrs])

  defp opts_to_attrs([{key, val} | t], attrs) when is_binary(key),
    do: opts_to_attrs(t, [[" ", key, "=\"", clean(val), "\""] | attrs])

  defp opts_to_attrs([], attrs), do: attrs

  defp width({a, b}), do: abs(a - b)
  defp min({a, b}), do: min(a, b)

  defp clean(s), do: Contex.SVG.Sanitize.basic_sanitize(s)
end
