defmodule Contex.Dataset do
@moduledoc """
`Dataset` is a simple wrapper around a datasource for plotting charts.

Dataset marshalls a couple of different data structures into a consistent form for consumption
by the chart plotting functions. For example, it allows a list of lists or a list of tuples to be
treated the same.

The most sensible way to work with a dataset is to provide column headers - it makes code elsewhere
readable. If you don't want to, you can also refer to columns by index.

Dataset provides a few convenience functions for calculating data extents for a column, extracting unique
values from columns, calculating combined extents for multiple columns (handy when plotting bar charts)
and guessing column type (handy when determining whether to use a `Contex.TimeScale` or a `Contex.ContinuousLinearScale`).

The easiest pattern to create a dataset is:
    iex> data = [
    ...>        {0.0, 0.0, "Hippo"},
    ...>        {0.5, 0.3, "Turtle"},
    ...>        {0.4, 0.3, "Turtle"},
    ...>        {0.2, 0.3, "Rabbit"}
    ...>        ] # Wherever your data comes from (e.g. could be straight from Ecto)
    ...> dataset = Dataset.new(data, ["x", "y", "category"]) # Attach descriptive headers
    ...> Dataset.column_extents(dataset, "x") # Get extents for a named column
    {0.0, 0.5}
    iex> Dataset.column_name(dataset, 0) # Get name of column by index
    "x"
    iex> cat_col = Dataset.column_index(dataset, "category") # Get index of column by name
    2
    iex> Enum.map(dataset.data, fn row -> # Enumerate values in a column
    ...>    Dataset.value(row, cat_col)
    ...> end)
    ["Hippo", "Turtle", "Turtle", "Rabbit"]
    iex> Dataset.unique_values(dataset, "category") # Extract unique values for legends etc.
    ["Hippo", "Turtle", "Rabbit"]

While Dataset gives facilities to map between names and column indexes, you can only access data values via index.
This is so that you don't have expensive mappings in tight loops.

**Note** There are very few validation checks (for example, to checks that number of headers supplied matches)
the size of each array or tuple in the data. If there are any issues finding a value, nil is returned.

"""


  alias __MODULE__
  alias Contex.Utils

  defstruct [:headers, :data, :title]

  @type column_name() :: String.t() | integer()
  @type column_type() :: :datetime | :number | :string | :unknown | nil
  @type row() :: list() | tuple()
  @type t() :: %__MODULE__{}

  @doc """
  Creates a new Dataset wrapper around some data.

  Data is expected to be a list of tuples of the same size or list of lists of same size.
  If no headers are specified, columns are access by index.
  """
  @spec new(list(row())) :: Contex.Dataset.t()
  def new(data) when is_list(data) do
    %Dataset{headers: nil, data: data}
  end

  @doc """
  Creates a new Dataset wrapper around some data with headers.

  Data is expected to be a list of tuples of the same size or list of lists of same size.
  """
  @spec new(list(row()), list(String.t())) :: Contex.Dataset.t()
  def new(data, headers) when is_list(data) and is_list(headers) do
    %Dataset{headers: headers, data: data}
  end

  @doc """
  Optionally sets a title.

  Not really used at the moment to be honest, but seemed like a good
  idea at the time. Might come in handy when overlaying plots.
  """
  @spec title(Contex.Dataset.t(), String.t()) :: Contex.Dataset.t()
  def title(%Dataset{}=dataset, title) do
    %{dataset | title: title}
  end

  @doc """
  Looks up the index for a given column name. Returns nil if not found.
  """
  @spec column_index(Contex.Dataset.t(), column_name()) :: nil | integer
  def column_index(%Dataset{headers: headers}=_dataset, column_name) when is_list(headers) do
    Enum.find_index(headers, fn col -> col == column_name end)
  end

  def column_index(_, column_name) when is_integer(column_name) do column_name end
  def column_index(_, _), do: nil


  @doc """
  Looks up the column name for a given index.

  If there are no headers, or the index is outside the range of the headers
  the requested index is returned.
  """
  @spec column_name(Contex.Dataset.t(), integer()) :: column_name()
  def column_name(%Dataset{headers: headers}=_dataset, column_index)
      when is_list(headers)
      and is_integer(column_index)
      and column_index < length(headers) # Maybe drop this guard and have it throw an exception
  do
    Enum.at(headers, column_index)
  end

  def column_name(_, column_index), do: column_index

  @doc """
  Looks up the value from a row based on the column index.

  This simply provides a consistent wrapper regardless of whether the data is represented in a tuple
  or a list.
  """
  @spec value(row(), integer()) :: any
  def value(row, column_index) when is_list(row) and is_integer(column_index), do: Enum.at(row, column_index, nil)
  def value(row, column_index) when is_tuple(row) and is_integer(column_index) and column_index < tuple_size(row) do
    elem(row, column_index)
  end
  def value(_, _), do: nil

  @doc """
  Calculates the min and max value in the specified column
  """
  @spec column_extents(Contex.Dataset.t(), column_name()) :: {any, any}
  def column_extents(%Dataset{data: data} = dataset, column_name) do
    index = column_index(dataset, column_name)

    Enum.reduce(data, {nil, nil},
        fn row, {min, max} ->
          val = value(row, index)
          {Utils.safe_min(val, min), Utils.safe_max(val, max)}
        end
    )
  end

  @doc """
  Tries to guess the data type for a column based on contained data.

  Looks through the rows and returns the first match it can find.
  """
  @spec guess_column_type(Contex.Dataset.t(), column_name()) :: column_type()
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
  defp evaluate_type(_), do: {:unknown}

  @doc """
  Calculates the data extents for the sum of the columns supplied.

  It is the equivalent of evaluating the extents of a calculated row where the calculating
  is the sum of the values identified by column_names.
  """
  @spec combined_column_extents(Contex.Dataset.t(), list(column_name())) :: {any(), any()}
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

  @doc """
  Extracts a list of unique values in the given column.

  Note that the unique values will maintain order of first detection
  in the data.
  """
  @spec unique_values(Contex.Dataset.t(), String.t() | integer()) :: [any]
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
