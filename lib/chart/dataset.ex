defmodule Contex.Dataset do
  @moduledoc """
  `Dataset` is a simple wrapper around a datasource for plotting charts.

  Dataset marshalls a couple of different data structures into a consistent form for consumption
  by the chart plotting functions. It allows a list of maps, list of lists or a list of tuples to be
  treated the same.

  The most sensible way to work with a dataset is to provide column headers - it makes code elsewhere
  readable. When the provided data is a list of maps, headers are inferred from the map keys. If you
  don't want to, you can also refer to columns by index.

  Dataset provides a few convenience functions for calculating data extents for a column, extracting unique
  values from columns, calculating combined extents for multiple columns (handy when plotting bar charts)
  and guessing column type (handy when determining whether to use a `Contex.TimeScale` or a `Contex.ContinuousLinearScale`).

  Datasets can be created from a list of maps:
      iex> data = [
      ...>        %{x: 0.0, y: 0.0, category: "Hippo"},
      ...>        %{x: 0.2, y: 0.3, category: "Rabbit"}
      ...>        ] # Wherever your data comes from (e.g. could be straight from Ecto)
      ...> dataset = Dataset.new(data)
      %Contex.Dataset{
        data: [
          %{category: "Hippo", x: 0.0, y: 0.0},
          %{category: "Rabbit", x: 0.2, y: 0.3}
        ],
        headers: nil,
        title: nil
      }
      iex> Dataset.column_names(dataset)
      [:category, :x, :y] # Note ordering of column names from map data is not guaranteed

  or from a list of tuples (or lists):
      iex> data = [
      ...>        {0.0, 0.0, "Hippo"},
      ...>        {0.5, 0.3, "Turtle"},
      ...>        {0.4, 0.3, "Turtle"},
      ...>        {0.2, 0.3, "Rabbit"}
      ...>        ]
      ...> dataset = Dataset.new(data, ["x", "y", "category"]) # Attach descriptive headers
      iex> Dataset.column_names(dataset)
      ["x", "y", "category"]
      ...> Dataset.column_extents(dataset, "x") # Get extents for a named column
      {0.0, 0.5}
      iex> Dataset.column_index(dataset, "x") # Get index of column by name
      0
      iex> category_col = Dataset.column_name(dataset, 2) # Get name of column by index
      "category"
      iex> Enum.map(dataset.data, fn row -> # Enumerate values in a column
      ...>    accessor = Dataset.value_fn(dataset, category_col)
      ...>    accessor.(row)
      ...> end)
      ["Hippo", "Turtle", "Turtle", "Rabbit"]
      iex> Dataset.unique_values(dataset, "category") # Extract unique values for legends etc.
      ["Hippo", "Turtle", "Rabbit"]

  Dataset gives facilities to map between names and column indexes. Where headers are not supplied (either directly or
  via map keys), the column index is treated as the column name internally. Data values are retrieved by column name
  using accessor functions, in order to avoid expensive mappings in tight loops.

  **Note** There are very few validation checks when a dataset is created (for example, to checks that number of headers
  supplied matches) the size of each array or tuple in the data. If there are any issues finding a value, nil is returned.
  """

  alias __MODULE__
  alias Contex.Utils

  defstruct [:headers, :data, :title]

  @type column_name() :: String.t() | integer() | atom()
  @type column_type() :: :datetime | :number | :string | :unknown | nil
  @type row() :: list() | tuple() | map()
  @type t() :: %__MODULE__{}

  @doc """
  Creates a new Dataset wrapper around some data.

  Data is expected to be a list of tuples of the same size, a list of lists of same size, or a list of maps with the same keys.
  Columns in map data are accessed by key. For lists of lists or tuples, if no headers are specified, columns are access by index.
  """
  @spec new(list(row())) :: Contex.Dataset.t()
  def new(data) when is_list(data) do
    %Dataset{headers: nil, data: data}
  end

  @doc """
  Creates a new Dataset wrapper around some data with headers.

  Data is expected to be a list of tuples of the same size or list of lists of same size. Headers provided with a list of maps
  are ignored; column names from map data are inferred from the maps' keys.
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
  def title(%Dataset{} = dataset, title) do
    %{dataset | title: title}
  end

  @doc """
  Looks up the index for a given column name. Returns nil if not found.
  """
  @spec column_index(Contex.Dataset.t(), column_name()) :: nil | column_name()
  def column_index(%Dataset{data: [first_row | _rest]}, column_name) when is_map(first_row) do
    if Map.has_key?(first_row, column_name) do
      column_name
    else
      nil
    end
  end

  def column_index(%Dataset{headers: headers}, column_name) when is_list(headers) do
    Enum.find_index(headers, fn col -> col == column_name end)
  end

  def column_index(_, column_name) when is_integer(column_name) do
    column_name
  end

  def column_index(_, _), do: nil

  # TODO: Should this be column_ids - they are essentially the internal column names
  @doc """
  Returns a list of the names of all of the columns in the dataset data (irrespective of
  whether the column names are mapped to plot elements).
  """
  @spec column_names(Contex.Dataset.t()) :: list(column_name())
  def column_names(%Dataset{data: [first_row | _]}) when is_map(first_row) do
    Map.keys(first_row)
  end

  def column_names(%Dataset{data: [first_row | _], headers: headers})
      when is_nil(headers) and is_tuple(first_row) do
    max = tuple_size(first_row) - 1
    0..max |> Enum.into([])
  end

  def column_names(%Dataset{data: [first_row | _], headers: headers})
      when is_nil(headers) and is_list(first_row) do
    max = length(first_row) - 1
    0..max |> Enum.into([])
  end

  def column_names(%Dataset{headers: headers}), do: headers

  @doc """
  Looks up the column name for a given index.

  If there are no headers, or the index is outside the range of the headers
  the requested index is returned.
  """
  @spec column_name(Contex.Dataset.t(), integer() | any) :: column_name()
  def column_name(%Dataset{headers: headers} = _dataset, column_index)
      when is_list(headers) and
             is_integer(column_index) and
             column_index < length(headers) do
    # Maybe drop the length guard above and have it throw an exception
    Enum.at(headers, column_index)
  end

  def column_name(_, column_index), do: column_index

  @doc """
  Returns a function that retrives the value for a given column in given row, accessed by
  the column name.

  ## Examples

    iex> data = [
    ...>        %{x: 0.0, y: 0.0, category: "Hippo"},
    ...>        %{x: 0.2, y: 0.3, category: "Rabbit"}
    ...>        ]
    iex> dataset = Dataset.new(data)
    iex> category_accessor = Dataset.value_fn(dataset, :category)
    iex> category_accessor.(hd(data))
    "Hippo"
  """
  @spec value_fn(Contex.Dataset.t(), column_name()) :: (row() -> any)
  def value_fn(%Dataset{data: [first_row | _]}, column_name)
      when is_map(first_row) and is_binary(column_name) do
    fn row -> row[column_name] end
  end

  def value_fn(%Dataset{data: [first_row | _]}, column_name)
      when is_map(first_row) and is_atom(column_name) do
    fn row -> row[column_name] end
  end

  def value_fn(%Dataset{data: [first_row | _]} = dataset, column_name) when is_list(first_row) do
    column_index = column_index(dataset, column_name)
    fn row -> Enum.at(row, column_index, nil) end
  end

  def value_fn(%Dataset{data: [first_row | _]} = dataset, column_name) when is_tuple(first_row) do
    column_index = column_index(dataset, column_name)

    if column_index < tuple_size(first_row) do
      fn row -> elem(row, column_index) end
    else
      fn _ -> nil end
    end
  end

  def value_fn(_dataset, _column_name), do: fn _ -> nil end

  @doc """
  Calculates the min and max value in the specified column
  """
  @spec column_extents(Contex.Dataset.t(), column_name()) :: {any, any}
  def column_extents(%Dataset{data: data} = dataset, column_name) do
    accessor = Dataset.value_fn(dataset, column_name)

    Enum.reduce(data, {nil, nil}, fn row, {min, max} ->
      val = accessor.(row)
      {Utils.safe_min(val, min), Utils.safe_max(val, max)}
    end)
  end

  @doc """
  Tries to guess the data type for a column based on contained data.

  Looks through the rows and returns the first match it can find.
  """
  @spec guess_column_type(Contex.Dataset.t(), column_name()) :: column_type()
  def guess_column_type(%Dataset{data: data} = dataset, column_name) do
    accessor = Dataset.value_fn(dataset, column_name)

    Enum.reduce_while(data, nil, fn row, _result ->
      val = accessor.(row)

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
    accessors =
      Enum.map(column_names, fn column_name -> Dataset.value_fn(dataset, column_name) end)

    Enum.reduce(data, {nil, nil}, fn row, {min, max} ->
      val = sum_row_values(row, accessors)
      {Utils.safe_min(val, min), Utils.safe_max(val, max)}
    end)
  end

  defp sum_row_values(row, accessors) do
    Enum.reduce(accessors, 0, fn accessor, acc ->
      val = accessor.(row)
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
    accessor = Dataset.value_fn(dataset, column_name)

    {result, _found} =
      Enum.reduce(data, {[], MapSet.new()}, fn row, {result, found} ->
        val = accessor.(row)

        case MapSet.member?(found, val) do
          true -> {result, found}
          _ -> {[val | result], MapSet.put(found, val)}
        end
      end)

    # Maintain order they are found in
    Enum.reverse(result)
  end
end
