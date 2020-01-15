defmodule Contex.Dataset do

  alias __MODULE__
  alias Contex.Utils

  defstruct [:headers, :data, :title]

  # Data is expected to be a list of tuples of the same size or list of lists of same size
  def new(data) when is_list(data) do
    %Dataset{headers: nil, data: data}
  end

  def new(data, headers) when is_list(data) and is_list(headers) do
    %Dataset{headers: headers, data: data}
  end

  def title(%Dataset{}=dataset, title) do
    %{dataset | title: title}
  end

  def column_index(%Dataset{headers: headers}, column_name) when is_list(headers) do
    Enum.find_index(headers, fn col -> col == column_name end)
  end

  def column_index(_, column_name) when is_integer(column_name) do column_name end
  def column_index(_, _), do: nil

  def column_name(%Dataset{headers: headers}, column_index)
      when is_list(headers)
      and is_integer(column_index)
      and column_index < length(headers) # Maybe drop this guard and have it throw an exception
  do
    Enum.at(headers, column_index)
  end

  def column_name(_, column_index), do: column_index

  def value(row, column_index) when is_list(row) do Enum.at(row, column_index, nil) end
  def value(row, column_index) when is_tuple(row) and column_index < tuple_size(row) do elem(row, column_index) end
  def value(_, _), do: nil

  def column_extents(%Dataset{data: data} = dataset, column_name) do
    index = column_index(dataset, column_name)

    Enum.reduce(data, {nil, nil},
        fn row, {min, max} ->
          val = value(row, index)
          {Utils.safe_min(val, min), Utils.safe_max(val, max)}
        end
    )
  end

  def guess_column_type(%Dataset{data: data} = dataset, column_name) do
    index = column_index(dataset, column_name)

    Enum.reduce_while(data, nil, fn row, _result ->
      val = value(row, index)
      case evaluate_type(val) do
        {:ok, type} -> {:halt, type}
        _ -> {:cont, nil}
      end
    end)
  end

  defp evaluate_type(%DateTime{}), do: {:ok, :datetime}
  defp evaluate_type(%NaiveDateTime{}), do: {:ok, :datetime}
  defp evaluate_type(v) when is_number(v), do: {:ok, :number}
  defp evaluate_type(v) when is_binary(v), do: {:ok, :string}
  defp evaluate_type(_), do: {:unknown_type}

  def combined_column_extents(%Dataset{data: data} = dataset, column_names) do
    indices = Enum.map(column_names, fn col -> column_index(dataset, col) end)

    Enum.reduce(data, {nil, nil},
        fn row, {min, max} ->
          val = sum_row_values(row, indices)
          {Utils.safe_min(val, min), Utils.safe_max(val, max)}
        end
    )
  end

  defp sum_row_values(row, indices) do
    Enum.reduce(indices, 0, fn index, acc ->
      val = value(row, index)
      Utils.safe_add(acc, val)
    end)
  end

  def unique_values(%Dataset{data: data} = dataset, column_name) do
    index = column_index(dataset, column_name)

    {result, _found} = Enum.reduce(data, {[], MapSet.new},
      fn row, {result, found} ->
        val = value(row, index)
        case MapSet.member?(found, val) do
          true -> {result, found}
          _ -> {[val | result], MapSet.put(found, val)}
        end
      end
    )

    # Maintain order they are found in
    Enum.reverse(result)
  end

end
