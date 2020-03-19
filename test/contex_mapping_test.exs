defmodule ContexMappingTest do
  use ExUnit.Case

  alias Contex.{Mapping, Dataset, PointPlot}

  setup do
    maps_data = Dataset.new([%{y: 1, x: 2, z: 5}, %{x: 3, y: 4, z: 6}])
    headers_data = Dataset.new([[1, 2, 3, 4], [4, 5, 6, 4], [-3, -2, -1, 0]], ["aa", "bb", "cccc", "d"])
    nocols_data = Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}])
    %{
      maps: struct(PointPlot, dataset: maps_data),
      headers: struct(PointPlot, dataset: headers_data),
      nocols: struct(PointPlot, dataset: nocols_data)
    }
  end

  describe "new!/3" do
    test "returns a mapping given valid inputs", plot_with do
      # Map data
      mapping =
        Mapping.map!(plot_with.maps, %{x_col: :x, y_cols: [:y, :z]})
        |> Map.get(:mapping)

      assert mapping.column_map.x_col == :x
      assert mapping.column_map.y_cols == [:y, :z]

      row = hd(plot_with.maps.dataset.data)
      assert mapping.accessors.x_col.(row) == 2
      assert Enum.map(mapping.accessors.y_cols, &(&1.(row))) == [1, 5]

      # List data with headers 
      mapping =
        Mapping.map!(plot_with.headers, %{x_col: "aa", y_cols: ["bb", "d"]})
        |> Map.get(:mapping)

      assert mapping.column_map.x_col == "aa"
      assert mapping.column_map.y_cols == ["bb", "d"]

      row = hd(plot_with.headers.dataset.data)
      assert mapping.accessors.x_col.(row) == 1
      assert Enum.map(mapping.accessors.y_cols, &(&1.(row))) == [2, 4]

      # Tuple data with no headers 
      mapping =
        Mapping.map!(plot_with.nocols, %{x_col: 0, y_cols: [1, 3]})
        |> Map.get(:mapping)

      assert mapping.column_map.x_col == 0
      assert mapping.column_map.y_cols == [1, 3]

      row = hd(plot_with.nocols.dataset.data)
      assert mapping.accessors.x_col.(row) == 1
      assert Enum.map(mapping.accessors.y_cols, &(&1.(row))) == [2, 4]
    end

    test "Maps default accessor for mappings not provided", plot_with do
      mapping =
        Mapping.map!(plot_with.maps, %{x_col: :x, y_cols: [:y, :z]})
        |> Map.get(:mapping)

      refute Map.has_key?(mapping.column_map, :fill_col)

      row = hd(plot_with.maps.dataset.data)
      assert mapping.accessors.fill_col.(row) == nil
    end

    test "Raises if required column not provided", plot_with do
      assert_raise(
        RuntimeError,
        "Required mapping(s) \"y_cols\" not included in column map.",
        fn -> Mapping.map!(plot_with.maps, %{x_col: :x}) end
      )
    end

    test "Raises if column in map is not in dataset", plot_with do
      assert_raise(
        RuntimeError,
        "Column(s) \"a\" in the column mapping not in the dataset.",
        fn -> Mapping.map!(plot_with.maps, %{x_col: :a, y_cols: [:y, :z]}) end
      )
    end
  end

  test "updates the column map and accessors", plot_with do
    mapping =
      Mapping.map!(plot_with.maps, %{x_col: :x, y_cols: [:y]})
      |> Mapping.map!(%{x_col: :z, fill_col: :x})
      |> Map.get(:mapping)

    assert mapping.column_map == %{x_col: :z, y_cols: [:y], fill_col: :x}
  end

  test "Raises if the updated columns are not in the dataset", plot_with do
    plot = Mapping.map!(plot_with.maps, %{x_col: :x, y_cols: [:y]})

    assert_raise(
      RuntimeError,
      "Column(s) \"a\" in the column mapping not in the dataset.",
      fn -> Mapping.map!(plot, %{x_col: :a, fill_col: :x}) end
    )
  end
end
