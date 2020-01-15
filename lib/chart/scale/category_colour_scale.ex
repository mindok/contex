defmodule Contex.CategoryColourScale do
  alias __MODULE__

  defstruct [:values, :colour_palette, :colour_map]

  @default_colour "fa8866"

  def new(raw_values) when is_list(raw_values) do
    values = Enum.uniq(raw_values)

    %CategoryColourScale{values: values}
    |> set_palette(:default)
  end

  def set_palette(%CategoryColourScale{} = scale, palette) when is_atom(palette) do
    set_palette(scale, get_palette(palette))
  end

  def set_palette(%CategoryColourScale{} = scale, palette) when is_list(palette) do
    %{scale | colour_palette: palette}
    |> map_values_to_palette
  end

  def colour_for_value(nil, _value), do: @default_colour

  def colour_for_value(%CategoryColourScale{colour_map: colour_map}, value) do
    case Map.fetch(colour_map, value) do
      {:ok, result} -> result
      _ -> @default_colour
    end
  end

  def colour_at_index(palette, index) when is_atom(palette) and is_integer(index) do
    case get_palette(palette) do
      nil -> @default_colour
      colour_palette -> get_colour(colour_palette, index)
    end
  end
  def colour_at_index(palette, index) when is_list(palette) and is_integer(index) do
    get_colour(palette, index)
  end

  def get_default_colour(), do: @default_colour


  defp map_values_to_palette(%CategoryColourScale{values: values, colour_palette: palette} = scale) do
    {_, colour_map} = Enum.reduce(values, {0, Map.new},
      fn(value, {index, current_result}) ->
        colour = get_colour(palette, index)
        {index + 1, Map.put(current_result, value, colour)}
      end
      )

    %{scale | colour_map: colour_map}
  end


  # "Inspired by" https://github.com/d3/d3-scale-chromatic/blob/master/src/categorical/category10.js
  @default_palette ["1f77b4", "ff7f0e", "2ca02c", "d62728", "9467bd", "8c564b", "e377c2", "7f7f7f", "bcbd22", "17becf"]
  defp get_palette(:default), do: @default_palette

  # "Inspired by" https://github.com/d3/d3-scale-chromatic/blob/master/src/categorical/Pastel1.js
  @pastel1_palette ["fbb4ae", "b3cde3", "ccebc5", "decbe4", "fed9a6", "ffffcc", "e5d8bd", "fddaec", "f2f2f2"]
  defp get_palette(:pastel1), do: @pastel1_palette

  defp get_palette(_), do: nil

  #TODO: We currently cycle the palette when we run out of colours. Probably should fade them (or similar)
  defp get_colour(colour_palette, index) when is_list(colour_palette) do
    palette_length = length(colour_palette)
    adjusted_index = rem(index, palette_length)
    Enum.at(colour_palette, adjusted_index)
  end

end
