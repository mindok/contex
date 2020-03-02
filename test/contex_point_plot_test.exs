defmodule ContexPointPlotTest do
  use ExUnit.Case

  alias Contex.{CategoryColourScale, Dataset, PointPlot}
  import SweetXml

  setup do
    plot =
      Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}], ["aa", "bb", "cccc", "d"])
      |> PointPlot.new()
    %{plot: plot}
  end

  # TODO
  # Why is width/height set here and not in defaults/1?
  describe "new/1" do
    test "returns a PointPlot struct with defaults", %{plot: plot} do
      assert plot.width == 100
      assert plot.height == 100
    end
  end

  # TODO
  # Separate test from new/1 is not really necessary but doing so
  # to highlight whether this should be public; why would you call
  # it except internally?
  describe "defaults/1" do
    test "returns a PointPlot struct with default properties", %{plot: plot} do
      assert plot.colour_palette == :default
      assert plot.x_col == "aa"
      assert plot.y_cols == ["bb"]
    end
  end

  # TODO
  # Should be able to validate atom is a valid palette. If colors
  # not limited to hex values validating those is harder.
  describe "colours/2" do
    test "accepts a list of (whatever)", %{plot: plot} do
      colours = ["blah", "blurgh", "blee"]
      plot = PointPlot.colours(plot, colours)
      assert plot.colour_palette == colours
    end

    test "accepts an atom (any atom)", %{plot: plot} do
      plot = PointPlot.colours(plot, :meat)
      assert plot.colour_palette == :meat
    end

    test "sets the palette to :default without an atom or list", %{plot: plot} do
      plot = PointPlot.colours(plot, 12345)
      assert plot.colour_palette == :default
    end
  end

  describe "set_size/3" do
    test "updates the height and width", %{plot: plot} do
      plot = PointPlot.set_size(plot, 666, 222)
      assert plot.width == 666
      assert plot.height == 222
    end
  end

  describe "get_svg_legend/1" do

    test "returns properly formatted legend", %{plot: plot} do
      {:safe, svg} =
        Contex.Plot.new(150, 150, plot)
        |> Contex.Plot.plot_options(%{legend_setting: :legend_right})
        |> Contex.Plot.to_svg()

      legend =
        IO.chardata_to_string(svg)
        |> xpath(~x"//g[@class='exc-legend']",
             box: [
               ~x"./rect",
               x: ~x"./@x"s,
               y: ~x"./@y"s,
               height: ~x"./@height"s,
               width: ~x"./@width"s,
               style: ~x"./@style"s
             ],
             text: [
               ~x"./text",
               x: ~x"./@x"s,
               y: ~x"./@y"s,
               text_anchor: ~x"./@text-anchor"s,
               dominant_baseline: ~x"./@dominant-baseline"s,
               text: ~x"./text()"s
             ]
           )

      # The other attributes are not tested because they are hard-coded.
      assert %{y: "0", style: "fill:#1f77b4;"} = legend.box
      assert %{y: "9", text: "bb"} = legend.text
    end
  end

  describe "to_svg/1" do

    defp plot_iodata_to_map(plot_iodata) do
      IO.chardata_to_string(plot_iodata)
      |> String.replace_prefix("", "<svg>")
      |> String.replace_suffix("", "</svg>")
      |> xpath(~x"//g/circle"l, [
        cx: ~x"./@cx"s,
        cy: ~x"./@cy"s,
        style: ~x"./@style"s
      ])
    end

    # Axis svg not tested as it is for practical purposes handled
    # by Contex.Axis, which is tested by ContexAxisTest
    test "returns properly constructed chart", %{plot: plot} do
      points_map =
        PointPlot.to_svg(plot)
        |> plot_iodata_to_map()

      assert ["fill:#1f77b4;"] ==
        Enum.map(points_map, fn point -> Map.get(point, :style) end)
        |> Enum.uniq()

      assert [{57.143, 42.857}, {100, 0}, {0, 100}] ==
        Enum.map(points_map, fn point ->
          {Map.get(point, :cx)
           |> String.to_float()
           |> Float.round(3),
           Map.get(point, :cy)
           |> String.to_float()
           |> Float.round(3)
          }
        end)
    end

    test "renders custom fill colors properly", %{plot: plot} do
      points_map =
        PointPlot.set_colour_col_name(plot, "d")
        |> PointPlot.to_svg()
        |> plot_iodata_to_map()

      assert 2 ==
        Enum.map(points_map, fn point -> Map.get(point, :style) end)
        |> Enum.uniq()
        |> Enum.count()

    end
  end

  # TODO
  # Not sure what happens if column name is invalid
  # Seems like you should also be allowed to specify an index
  # Need to test reset of scale
  describe "set_x_col_name/2" do
    test "sets x column to specified dataset column", %{plot: plot} do
      plot = PointPlot.set_x_col_name(plot, "cccc")
      assert plot.x_col == "cccc"
    end
  end

  # TODO
  # Not sure what happens if column name is invalid
  # Seems like you should also be allowed to specify indexes
  # Need to test reset of scale
  describe "set_y_col_names/2" do
    test "sets y column(s) to specified dataset column(s)", %{plot: plot} do
      plot = PointPlot.set_y_col_names(plot, ["aa", "bb"])
      assert plot.y_cols == ["aa", "bb"]
    end
  end

  describe "set_colour_col_name/2" do
    test "sets the fill color column to the given column", %{plot: plot} do
      plot = PointPlot.set_colour_col_name(plot, "cccc")
      assert plot.fill_col == "cccc"
    end

    test "sets the fill scale to the unique values of the given column", %{plot: plot} do
      plot = PointPlot.set_colour_col_name(plot, "d")
      assert %CategoryColourScale{values: [4, 0]} = plot.fill_scale
    end
  end
end
