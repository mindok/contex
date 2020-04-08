defmodule ContexBarChartTest do
  use ExUnit.Case

  alias Contex.{Dataset, BarChart, Plot}
  import SweetXml

  setup do
    plot =
      Dataset.new([{"Category 1", 10, 20}, {"Category 2", 30, 40}], [
        "Category",
        "Series 1",
        "Series 2"
      ])
      |> BarChart.new()

    %{plot: plot}
  end

  # TODO
  # Why is width/height set here and not in defaults/1?
  describe "new/2" do
    test "given data from tuples or lists, returns a BarChart struct with defaults", %{plot: plot} do
      assert plot.width == 100
      assert plot.height == 100
    end

    test "given data from a map and a valid column map, returns a BarChart struct accordingly" do
      plot =
        Dataset.new([%{"bb" => 2, "aa" => 2}, %{"bb" => 3, "aa" => 4}])
        |> BarChart.new(mapping: %{category_col: "bb", value_cols: ["aa"]})

      assert plot.width == 100
      assert plot.height == 100
      assert plot.mapping.column_map.category_col == "bb"
      assert plot.mapping.column_map.value_cols == ["aa"]
    end

    test "Raises if no mapping is passed with map data" do
      assert_raise(
        ArgumentError,
        "Can not create default data mappings with Map data.",
        fn ->
          Dataset.new([%{"bb" => 2, "aa" => 2}, %{"bb" => 3, "aa" => 4}])
          |> BarChart.new()
        end
      )
    end

    test "Raises if invalid column map is passed with map data" do
      assert_raise(
        RuntimeError,
        "Required mapping(s) \"category_col\" not included in column map.",
        fn ->
          Dataset.new([%{"bb" => 2, "aa" => 2}, %{"bb" => 3, "aa" => 4}])
          |> BarChart.new(mapping: %{x_col: "bb", value_cols: ["aa"]})
        end
      )
    end
  end

  describe "data_labels/2" do
    test "sets the data labels value", %{plot: plot} do
      plot = BarChart.data_labels(plot, false)
      assert plot.data_labels == false
    end
  end

  describe "type/2" do
    test "sets the plot type", %{plot: plot} do
      plot = BarChart.type(plot, :grouped)
      assert plot.type == :grouped
    end
  end

  describe "orientation/2" do
    test "sets the orientation", %{plot: plot} do
      plot = BarChart.orientation(plot, :horizontal)
      assert plot.orientation == :horizontal
    end
  end

  describe "force_value_range/2" do
    test "sets the value range", %{plot: plot} do
      plot = BarChart.force_value_range(plot, {100, 200})
      assert plot.value_range == {100, 200}
    end
  end

  describe "axis_label_rotation/2" do
    test "sets the axis label rotation", %{plot: plot} do
      plot = BarChart.axis_label_rotation(plot, 45)
      assert plot.axis_label_rotation == 45
    end

    test "rotates the labels when set", %{plot: plot} do
      plot = BarChart.axis_label_rotation(plot, 45)

      assert ["rotate(-45)"] ==
               Plot.new(200, 200, plot)
               |> Plot.to_svg()
               |> elem(1)
               |> IO.chardata_to_string()
               |> xpath(~x"/svg/g/g/g/text/@transform"sl)
               |> Enum.uniq()
    end
  end

  describe "padding/2" do
    test "sets padding and updates scale padding", %{plot: plot} do
      plot = BarChart.padding(plot, 4)
      assert plot.padding == 4
      assert plot.category_scale.padding == 4
    end

    # Not testing clause where category scale is not ordinal, since there is
    # presently no way to set it to anything other than ordinal
    # test "if category scale is not ordinal, just sets padding", %{plot: plot} do
    #   plot = BarChart.padding(plot, 4)
    #   assert plot.padding == 4
    # end
  end

  # Should be able to validate atom is a valid palette. If colors
  # not limited to hex values validating those is harder.
  describe "colours/2" do
    test "accepts a list of (whatever)", %{plot: plot} do
      colours = ["blah", "blurgh", "blee"]
      plot = BarChart.colours(plot, colours)
      assert plot.colour_palette == colours
    end

    test "accepts an atom (any atom)", %{plot: plot} do
      plot = BarChart.colours(plot, :meat)
      assert plot.colour_palette == :meat
    end

    test "sets the palette to :default without an atom or list", %{plot: plot} do
      plot = BarChart.colours(plot, 12345)
      assert plot.colour_palette == :default
    end
  end

  describe "event_handler/2" do
    test "sets the Phoenix event handler", %{plot: plot} do
      plot = BarChart.event_handler(plot, "clicked")
      assert plot.phx_event_handler == "clicked"
    end
  end

  describe "select_item/2" do
    # TODO
    # This shouldn't work since select item is supposed to be a map
    # with certain keys
    test "sets the selected item", %{plot: plot} do
      plot = BarChart.select_item(plot, :meat)
      assert plot.select_item == :meat
    end
  end

  describe "custom_value_formatter/2" do
    test "sets the custom value formatter when passed nil", %{plot: plot} do
      plot = BarChart.custom_value_formatter(plot, nil)
      assert plot.custom_value_formatter == nil
    end

    test "sets the custom value formatter when passed a function", %{plot: plot} do
      format_function = fn x -> x end
      plot = BarChart.custom_value_formatter(plot, format_function)
      assert plot.custom_value_formatter == format_function
    end

    test "raises when not passed a function or nil", %{plot: plot} do
      assert_raise FunctionClauseError, fn -> BarChart.custom_value_formatter(plot, :meat) end
    end
  end

  describe "to_svg/1" do
    defp plot_iodata_to_map(plot_iodata) do
      IO.chardata_to_string(plot_iodata)
      |> xpath(~x"//g/rect"l,
        x: ~x"./@x"s,
        y: ~x"./@y"s,
        width: ~x"./@width"s,
        height: ~x"./@height"s,
        title: ~x"./title/text()"s
      )
    end

    # Axis and legend svg not tested as they are for practical purposes handled
    # by Contex.Axis and Context.Legend, tested separately
    test "returns properly constructed chart", %{plot: plot} do
      plot = BarChart.set_val_col_names(plot, ["Series 1", "Series 2"])

      rects_map =
        Plot.new(200, 200, plot)
        |> Plot.to_svg()
        |> elem(1)
        |> plot_iodata_to_map()

      string_to_rounded_float = fn value ->
        Float.parse(value)
        |> elem(0)
        |> Float.round(3)
      end

      assert [
               [17.143, 58.0, 1.0, 102.857],
               [34.286, 58.0, 1.0, 68.571],
               [51.429, 58.0, 61.0, 68.571],
               [68.571, 58.0, 61.0, 0.0]
             ] ==
               Stream.map(rects_map, &Map.delete(&1, :title))
               |> Stream.map(&Enum.unzip/1)
               |> Stream.map(fn value ->
                 elem(value, 1)
               end)
               |> Enum.map(fn value ->
                 Enum.map(value, string_to_rounded_float)
               end)

      assert ["10", "20", "30", "40"] ==
               Enum.map(rects_map, &Map.get(&1, :title))
    end

    test "generates equivalent output when passed map data", %{plot: plot} do
      map_plot_svg =
        Dataset.new([
          %{"Category" => "Category 1", "Series 1" => 10, "Series_2" => 20},
          %{"Category" => "Category 2", "Series 1" => 30, "Series_2" => 40}
        ])
        |> Plot.new(BarChart, 200, 200,
          mapping: %{category_col: "Category", value_cols: ["Series 1"]}
        )
        |> Plot.to_svg()

      assert map_plot_svg ==
               plot.dataset
               |> Plot.new(BarChart, 200, 200)
               |> Plot.to_svg()
    end
  end

  # TODO
  # Need to test reset of scale
  describe "set_cat_col_name/2" do
    test "sets category column to specified dataset column", %{plot: plot} do
      plot = BarChart.set_cat_col_name(plot, "Series 2")
      assert plot.mapping.column_map.category_col == "Series 2"
    end
  end

  # TODO
  # Need to test reset of scale
  describe "set_val_col_names/2" do
    test "sets value column(s) to specified dataset column(s)", %{plot: plot} do
      plot = BarChart.set_val_col_names(plot, ["Series 1", "Series 2"])
      assert plot.mapping.column_map.value_cols == ["Series 1", "Series 2"]
    end
  end
end
