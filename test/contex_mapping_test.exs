defmodule ContexMappingTest do
  use ExUnit.Case

  alias Contex.{Mapping, Dataset, PointPlot}

  setup do
    maps_data = Dataset.new([%{y: 1, x: 2, z: 5}, %{x: 3, y: 4, z: 6}])

    headers_data =
      Dataset.new([[1, 2, 3, 4], [4, 5, 6, 4], [-3, -2, -1, 0]], ["aa", "bb", "cccc", "d"])

    nocols_data = Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}])

    %{
      maps: struct(PointPlot, dataset: maps_data),
      headers: struct(PointPlot, dataset: headers_data),
      nocols: struct(PointPlot, dataset: nocols_data),
      maps_data: maps_data,
      headers_data: headers_data,
      nocols_data: nocols_data,
      required_columns: [x_col: :exactly_one, y_cols: :one_or_more, fill_col: :zero_or_one]
    }
  end

  describe "new!/3" do
    test "returns a mapping given valid inputs", plot_with do
      # Map data
      mapping =
        Mapping.new(
          plot_with.required_columns,
          %{x_col: :x, y_cols: [:y, :z]},
          plot_with.maps_data
        )

      assert mapping.column_map.x_col == :x
      assert mapping.column_map.y_cols == [:y, :z]

      row = hd(plot_with.maps.dataset.data)
      assert mapping.accessors.x_col.(row) == 2
      assert Enum.map(mapping.accessors.y_cols, & &1.(row)) == [1, 5]

      # List data with headers
      mapping =
        Mapping.new(
          plot_with.required_columns,
          %{x_col: "aa", y_cols: ["bb", "d"]},
          plot_with.headers_data
        )

      assert mapping.column_map.x_col == "aa"
      assert mapping.column_map.y_cols == ["bb", "d"]

      row = hd(plot_with.headers.dataset.data)
      assert mapping.accessors.x_col.(row) == 1
      assert Enum.map(mapping.accessors.y_cols, & &1.(row)) == [2, 4]

      # Tuple data with no headers
      mapping =
        Mapping.new(
          plot_with.required_columns,
          %{x_col: 0, y_cols: [1, 3]},
          plot_with.nocols_data
        )

      assert mapping.column_map.x_col == 0
      assert mapping.column_map.y_cols == [1, 3]

      row = hd(plot_with.nocols.dataset.data)
      assert mapping.accessors.x_col.(row) == 1
      assert Enum.map(mapping.accessors.y_cols, & &1.(row)) == [2, 4]
    end

    test "Maps default accessor for mappings not provided", plot_with do
      mapping =
        Mapping.new(
          plot_with.required_columns,
          %{x_col: :x, y_cols: [:y, :z]},
          plot_with.maps_data
        )

      # A mapping should pick up all the expected columns...
      assert Map.has_key?(mapping.column_map, :fill_col)

      row = hd(plot_with.maps.dataset.data)
      # ... but return nil for an unmapped one
      assert mapping.accessors.fill_col.(row) == nil
    end

    test "Raises if required column not provided", plot_with do
      assert_raise(
        RuntimeError,
        "Required mapping(s) \"y_cols\" not included in column map.",
        fn -> Mapping.new(plot_with.required_columns, %{x_col: :x}, plot_with.maps_data) end
      )
    end

    test "Raises if column in map is not in dataset", plot_with do
      assert_raise(
        RuntimeError,
        "Column(s) \"a\" in the column mapping not in the dataset.",
        fn ->
          Mapping.new(
            plot_with.required_columns,
            %{x_col: :a, y_cols: [:y, :z]},
            plot_with.maps_data
          )
        end
      )
    end
  end

  test "updates the column map and accessors", plot_with do
    mapping =
      Mapping.new(plot_with.required_columns, %{x_col: :x, y_cols: [:y]}, plot_with.maps_data)
      |> Mapping.update(%{x_col: :z, fill_col: :x})

    assert mapping.column_map == %{x_col: :z, y_cols: [:y], fill_col: :x}
  end

  test "Raises if the updated columns are not in the dataset", plot_with do
    mapping =
      Mapping.new(plot_with.required_columns, %{x_col: :x, y_cols: [:y, :z]}, plot_with.maps_data)

    assert_raise(
      RuntimeError,
      "Column(s) \"a\" in the column mapping not in the dataset.",
      fn -> Mapping.update(mapping, %{x_col: :a, fill_col: :x}) end
    )
  end
end
