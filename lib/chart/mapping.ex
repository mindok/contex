defmodule Contex.Mapping do
  @moduledoc false
  alias __MODULE__

  defstruct [:x, :y, :colour, :size, :x_index, :y_index, :colour_index, :size_index]

  @doc """
  CURRENTLY NOT USED....
  Manages the mapping between generic data and the elements required to render specific plot types
  Along the lines of ggplot -> aes() (Aesthetic mapping)
  """
  def new(x, y, opts \\ []) do
    mapping = new(opts)
    %{mapping | x: x, y: y}
  end

  def new(opts \\ []) do
    x = Keyword.get(opts, :x, nil)
    y = Keyword.get(opts, :y, nil)
    colour = Keyword.get(opts, :colour, nil)
    size = Keyword.get(opts, :size, nil)

    %Mapping{x: x, y: y, colour: colour, size: size}
  end

  @doc """
  This function figures out the indexes into required data columns based on the mapping definition
  and a list of column names (headers paramete
  headers should be a list of either atoms or strings ordered in the same way as the data columns
  """
  def prepare(%Mapping{}=mapping, headers) do
    x_index = get_index(mapping.x, headers)
    y_index = get_index(mapping.y, headers)
    colour_index = get_index(mapping.colour, headers)
    size_index = get_index(mapping.size, headers)

    %{mapping | x_index: x_index, y_index: y_index, colour_index: colour_index, size_index: size_index}
  end

  defp get_index(nil, _), do: nil
  defp get_index(mapped_col, headers) do
    {_val, index}
      = headers
      |> Enum.with_index()
      |> Enum.find({mapped_col, nil}, fn {value, _i} -> value == mapped_col end)

    index
  end

end
