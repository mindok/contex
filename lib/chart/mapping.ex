defmodule Contex.Mapping do
  @moduledoc """
  Mappings generalize the process of associating columns in the dataset to the
  elements of a plot. As part of creating a mapping, these associations are
  validated to confirm that a column has been assigned to each of the graphical
  elements that are necessary to draw the plot, and that all of the assigned columns
  exist in the dataset.

  The Mapping struct stores accessor functions for the assigned columns, which
  are used to retrieve values for those columns from the dataset to support
  drawing the plot. The accessor functions have the same name as the associated
  plot element; this allows plot-drawing functions to access data based that plot's
  required elements without knowing anything about the dataset.
  """

  alias Contex.{Dataset}

  defstruct [:column_map, :accessors, :expected_mappings, :dataset]

  @type t() :: %__MODULE__{}

  @doc """
  Given expected mappings for a plot and a map associating plot elements with dataset
  columns, creates a Mapping struct for the plot that stores accessor functions for
  each element and returns a mapping. Raises if the map does not include all
  required elements of the specified plot type or if the dataset columns are not
  present in the dataset.

  Expected mappings are passed as a keyword list where each plot element is one
  of the following:

  * `:exactly_one` - indicates that the plot needs exactly one of these elements, for
  example a column representing categories in a barchart.
  * `:one_more_more` - indicates that the plot needs at least one of these elements,
  for example y columns in a point plot
  * `:zero_or_one` - indicates that the plot will use one of these elements if it
  is available, for example a fill colour column in a point plot
  * `:zero_or_more` - indicates that plot will use one or more of these elements if it
  is available

  For example, the expected mappings for a barchart are represented as follows:
  `[category_col: :exactly_one, value_cols: :one_or_more]`

  and for a point point:
  `[ x_col: :exactly_one, y_cols: :one_or_more, fill_col: :zero_or_one]`

  Provided mappings are passed as a map with the map key matching the expected mapping
  and the map value representing the columns in the underlying dataset. So for a barchart
  the column mappings may be:
  `%{category_col: "Quarter", value_cols: ["Australian Sales", "Kiwi Sales", "South African Sales"]}`

  If columns are not specified for optional plot elements, an accessor function
  that returns `nil` is created for those elements.
  """
  @spec new(keyword(), map(), Contex.Dataset.t()) :: Contex.Mapping.t()
  def new(expected_mappings, provided_mappings, %Dataset{} = dataset) do
    column_map = check_mappings(provided_mappings, expected_mappings, dataset)
    mapped_accessors = accessors(dataset, column_map)

    %__MODULE__{
      column_map: column_map,
      expected_mappings: expected_mappings,
      dataset: dataset,
      accessors: mapped_accessors
    }
  end

  @doc """
  Given a plot that already has a mapping and a new map of elements to columns,
  updates the mapping accordingly and returns the plot.
  """
  @spec update(Contex.Mapping.t(), map()) :: Contex.Mapping.t()
  def update(
        %__MODULE__{expected_mappings: expected_mappings, dataset: dataset} = mapping,
        updated_mappings
      ) do
    column_map =
      Map.merge(mapping.column_map, updated_mappings)
      |> check_mappings(expected_mappings, dataset)

    mapped_accessors = accessors(dataset, column_map)

    %{mapping | column_map: column_map, accessors: mapped_accessors}
  end

  defp check_mappings(nil, expected_mappings, %Dataset{} = dataset) do
    check_mappings(default_mapping(expected_mappings, dataset), expected_mappings, dataset)
  end

  defp check_mappings(mappings, expected_mappings, %Dataset{} = dataset) do
    add_nil_for_optional_mappings(mappings, expected_mappings)
    |> validate_mappings(expected_mappings, dataset)
  end

  defp default_mapping(_expected_mappings, %Dataset{data: [first | _rest]} = _dataset)
       when is_map(first) do
    raise(ArgumentError, "Can not create default data mappings with Map data.")
  end

  defp default_mapping(expected_mappings, %Dataset{} = dataset) do
    Enum.with_index(expected_mappings)
    |> Enum.reduce(%{}, fn {{expected_mapping, expected_count}, index}, mapping ->
      column_name = Dataset.column_name(dataset, index)

      column_names =
        case expected_count do
          :exactly_one -> column_name
          :one_or_more -> [column_name]
          :zero_or_one -> nil
          :zero_or_more -> [nil]
        end

      Map.put(mapping, expected_mapping, column_names)
    end)
  end

  defp add_nil_for_optional_mappings(mappings, expected_mappings) do
    Enum.reduce(expected_mappings, mappings, fn {expected_mapping, expected_count}, mapping ->
      case expected_count do
        :zero_or_one ->
          if mapping[expected_mapping] == nil,
            do: Map.put(mapping, expected_mapping, nil),
            else: mapping

        :zero_or_more ->
          if mapping[expected_mapping] == nil,
            do: Map.put(mapping, expected_mapping, [nil]),
            else: mapping

        _ ->
          mapping
      end
    end)
  end

  defp validate_mappings(provided_mappings, expected_mappings, %Dataset{} = dataset) do
    # TODO: Could get more precise by looking at how many mapped dataset columns are expected
    check_required_columns!(expected_mappings, provided_mappings)
    confirm_columns_in_dataset!(dataset, provided_mappings)

    provided_mappings
  end

  defp check_required_columns!(expected_mappings, column_map) do
    required_mappings = Enum.map(expected_mappings, fn {k, _v} -> k end)

    provided_mappings = Map.keys(column_map)
    missing_mappings = missing_columns(required_mappings, provided_mappings)

    case missing_mappings do
      [] ->
        :ok

      mappings ->
        mapping_string = Enum.map_join(mappings, ", ", &"\"#{&1}\"")
        raise "Required mapping(s) #{mapping_string} not included in column map."
    end
  end

  defp confirm_columns_in_dataset!(dataset, column_map) do
    available_columns = [nil | Dataset.column_names(dataset)]

    missing_columns =
      Map.values(column_map)
      |> List.flatten()
      |> missing_columns(available_columns)

    case missing_columns do
      [] ->
        :ok

      columns ->
        column_string = Enum.map_join(columns, ", ", &"\"#{&1}\"")
        raise "Column(s) #{column_string} in the column mapping not in the dataset."
    end
  end

  defp missing_columns(required_columns, provided_columns) do
    MapSet.new(required_columns)
    |> MapSet.difference(MapSet.new(provided_columns))
    |> MapSet.to_list()
  end

  defp accessors(dataset, column_map) do
    Enum.map(column_map, fn {mapping, columns} ->
      {mapping, accessor(dataset, columns)}
    end)
    |> Enum.into(%{})
  end

  defp accessor(dataset, columns) when is_list(columns) do
    Enum.map(columns, &accessor(dataset, &1))
  end

  defp accessor(_dataset, nil) do
    fn _row -> nil end
  end

  defp accessor(dataset, column) do
    Dataset.value_fn(dataset, column)
  end
end
