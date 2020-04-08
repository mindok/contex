defmodule Contex.CategoryColourScale do
  @moduledoc """
  Maps categories to colours.

  The `Contex.CategoryColourScale` maps categories to a colour palette. It is used, for example, to calculate
  the fill colours for `Contex.BarChart`, or to calculate the colours for series in `Contex.PointPlot`.

  Internally it is a very simple map with some convenience methods to handle duplicated data inputs,
  cycle through colours etc.

  The mapping is done on a first identified, first matched basis from the provided dataset. So, for example,
  if you have a colour palette of `["ff0000", "00ff00", "0000ff"]` (aka red, green, blue), the mapping
  for a dataset would be as follows:

  X | Y | Category | Mapped Colour
  -- | - | -------- | -------------
  0 | 0 | Turtle | red
  1 | 1 | Turtle | red
  0 | 1 | Camel | green
  2 | 1 | Brontosaurus | blue
  3 | 4 | Turtle | red
  5 | 5 | Brontosaurus | blue
  6 | 7 | Hippopotamus | red &larr; *NOTE* - if you run out of colours, they will cycle

  Tn use, the `CategoryColourScale` is created with a list of values to map to colours and optionally a colour
  palette. If using with a `Contex.Dataset`, it would be initialised like this:

  ```
  dataset = Dataset.new(data, ["X", "Y", "Category"])
  colour_scale
    = dataset
    |> Dataset.unique_values("Category")
    |> CategoryColourScale(["ff0000", "00ff00", "0000ff"])
  ```
  Then it can be used to look up colours for values as needed:

  ```
  fill_colour = CategoryColourScale.colour_for_value(colour_scale, "Brontosaurus") // returns "0000ff"
  ```

  There are a number of built-in colour palettes - see `colour_palette()`, but you can supply your own by
  providing a list of strings representing hex code of the colour as per CSS colour hex codes, but without the #. For example:

    ```
    scale = CategoryColourScale.set_palette(scale, ["fbb4ae", "b3cde3", "ccebc5"])
    ```
  """
  alias __MODULE__

  defstruct [:values, :colour_palette, :colour_map, :default_colour]

  @type t() :: %__MODULE__{}
  @type colour_palette() :: nil | :default | :pastel1 | :warm | list()

  @default_colour "fa8866"

  @doc """
  Create a new CategoryColourScale from a list of values.

  Optionally attach a colour palette.
  Pretty well any value list can be used so long as it can be a key in a map.
  """
  @spec new(list(), colour_palette()) :: Contex.CategoryColourScale.t()
  def new(raw_values, palette \\ :default) when is_list(raw_values) do
    values = Enum.uniq(raw_values)

    %CategoryColourScale{values: values}
    |> set_palette(palette)
  end

  @doc """
  Update the colour palette used for the scale
  """
  @spec set_palette(Contex.CategoryColourScale.t(), colour_palette()) ::
          Contex.CategoryColourScale.t()
  def set_palette(%CategoryColourScale{} = colour_scale, nil),
    do: set_palette(colour_scale, :default)

  def set_palette(%CategoryColourScale{} = colour_scale, palette) when is_atom(palette) do
    set_palette(colour_scale, get_palette(palette))
  end

  def set_palette(%CategoryColourScale{} = colour_scale, palette) when is_list(palette) do
    %{colour_scale | colour_palette: palette}
    |> map_values_to_palette()
  end

  @doc """
  Sets the default colour for the scale when it isn't possible to look one up for a value
  """
  def set_default_colour(%CategoryColourScale{} = colour_scale, colour) do
    %{colour_scale | default_colour: colour}
  end

  @doc """
  Look up a colour for a value from the palette.
  """
  @spec colour_for_value(Contex.CategoryColourScale.t() | nil, any()) :: String.t()
  def colour_for_value(nil, _value), do: @default_colour

  def colour_for_value(%CategoryColourScale{colour_map: colour_map} = colour_scale, value) do
    case Map.fetch(colour_map, value) do
      {:ok, result} -> result
      _ -> get_default_colour(colour_scale)
    end
  end

  @doc """
  Get the default colour. Surprise.
  """
  @spec get_default_colour(Contex.CategoryColourScale.t() | nil) :: String.t()
  def get_default_colour(%CategoryColourScale{default_colour: default} = _colour_scale)
      when is_binary(default),
      do: default

  def get_default_colour(_), do: @default_colour

  defp map_values_to_palette(
         %CategoryColourScale{values: values, colour_palette: palette} = colour_scale
       ) do
    {_, colour_map} =
      Enum.reduce(values, {0, Map.new()}, fn value, {index, current_result} ->
        colour = get_colour(palette, index)
        {index + 1, Map.put(current_result, value, colour)}
      end)

    %{colour_scale | colour_map: colour_map}
  end

  # "Inspired by" https://github.com/d3/d3-scale-chromatic/blob/master/src/categorical/category10.js
  @default_palette [
    "1f77b4",
    "ff7f0e",
    "2ca02c",
    "d62728",
    "9467bd",
    "8c564b",
    "e377c2",
    "7f7f7f",
    "bcbd22",
    "17becf"
  ]
  defp get_palette(:default), do: @default_palette

  # "Inspired by" https://github.com/d3/d3-scale-chromatic/blob/master/src/categorical/Pastel1.js
  @pastel1_palette [
    "fbb4ae",
    "b3cde3",
    "ccebc5",
    "decbe4",
    "fed9a6",
    "ffffcc",
    "e5d8bd",
    "fddaec",
    "f2f2f2"
  ]
  defp get_palette(:pastel1), do: @pastel1_palette

  # Warm colours - see https://learnui.design/tools/data-color-picker.html#single
  @warm_palette ["d40810", "e76241", "f69877", "ffcab4", "ffeac4", "fffae4"]
  defp get_palette(:warm), do: @warm_palette

  defp get_palette(_), do: nil

  # TODO: We currently cycle the palette when we run out of colours. Probably should fade them (or similar)
  defp get_colour(colour_palette, index) when is_list(colour_palette) do
    palette_length = length(colour_palette)
    adjusted_index = rem(index, palette_length)
    Enum.at(colour_palette, adjusted_index)
  end
end
