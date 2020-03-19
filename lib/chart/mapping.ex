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

  alias __MODULE__
  alias Contex.{Dataset}

  defstruct [:column_map, :accessors]

  @type t() :: %__MODULE__{}
  @type row() :: tuple() | list() | map()
  @type plot() :: Contex.PointPlot.t() | Contex.BarChart.t() | Contex.GanttChart.t()

  @doc """
  Given a plot with no mapping and a map associating plot elements with dataset
  columns, creates a Mapping struct for the plot that stores accessor functions for
  each element and returns the updated plot. Raises if the map does not include all
  required elements of the specified plot type or if the dataset columns are not
  present in the dataset.

  If columns are not specified for optional plot elements, an accessor function
  that returns `nil` is created for those elements.

  Given a plot that already has a mapping and a new map of elements to columns,
  updates the mapping accordingly and returns the plot.
  """
  @spec map!(plot(), map()) :: plot()
  def map!(%_{mapping: nil} = plot, column_map) do
    %{plot | mapping: %{column_map: %{}}}
    |> Mapping.map!(column_map)
  end

  def map!(%plot_type{mapping: mapping, dataset: dataset} = plot, column_map) do
    column_map = Map.merge(mapping.column_map, column_map)
    check_required_columns!(plot_type, column_map)
    confirm_columns_in_dataset!(dataset, column_map)

    mapped_accessors = accessors(dataset, column_map)
    unmapped_accessors = default_accessors(plot_type, column_map)
    accessors = Map.merge(mapped_accessors, unmapped_accessors)

    %{plot | mapping: %Mapping{column_map: column_map, accessors: accessors}}
  end

  defp check_required_columns!(plot_type, column_map) do
    required_mappings = apply(plot_type, :required_mappings, [])
    provided_mappings = Map.keys(column_map)
    missing_mappings = missing_columns(required_mappings, provided_mappings)

    case missing_mappings do
      [] -> :ok
      mappings ->
        mapping_string = Enum.map_join(mappings, ", ", &("\"#{&1}\""))
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
      [] -> :ok
      columns ->
        column_string = Enum.map_join(columns, ", ", &("\"#{&1}\""))
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
    Enum.map(columns, &(accessor(dataset, &1)))
  end

  defp accessor(dataset, column) do
    Dataset.value_fn(dataset, column)
  end

  defp default_accessors(plot_type, column_map) do
    optional_mappings = apply(plot_type, :optional_mappings, [])
    provided_mappings = Map.keys(column_map)
    missing_mappings = missing_columns(optional_mappings, provided_mappings)

    Enum.map(missing_mappings, fn mapping ->
      {mapping, default_accessor()}
    end)
    |> Enum.into(%{})
  end

  defp default_accessor(), do: fn _mapping -> nil end
end
