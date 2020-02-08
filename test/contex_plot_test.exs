defmodule ContexPlotTest do
  use ExUnit.Case

  alias Contex.{Plot, Dataset, PointPlot}
  import SweetXml

  setup do
    plot = 
      Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}], ["aa", "bb", "cccc", "d"])
      |> PointPlot.new()
    
    plot = Plot.new(150, 200, plot)
    %{plot: plot}
  end

  describe "new/3" do
    test "returns a Plot struct with default options and margins", %{plot: plot} do
      assert plot.width == 150
      assert plot.height == 200
      assert plot.plot_options == %{
        show_x_axis: true,
        show_y_axis: true,
        legend_setting: :legend_none
      }
      assert plot.margins == %{
        left: 70,
        top: 10,
        right: 10,
        bottom: 70
      }
    end
  end

  describe "plot_options/2" do
    setup context do
      %{plot: Plot.plot_options(context.plot, %{show_y_axis: false, legend_setting: :legend_right})}
    end

    test "sets plot options", %{plot: plot} do
      assert plot.plot_options == %{
        show_x_axis: true,
        show_y_axis: false,
        legend_setting: :legend_right
      }
    end

    test "recalculates margins", %{plot: plot} do
      assert plot.margins == %{
        left: 0,
        top: 10,
        right: 110,
        bottom: 70
      }
    end
  end

  describe "titles/3" do
    setup context do
      %{plot: Plot.titles(context.plot, "The Title", "The Sub")}
    end

    test "sets title and subtitle", %{plot: plot} do
      assert plot.title == "The Title"
      assert plot.subtitle == "The Sub"
    end

    test "recalculates margins", %{plot: plot} do
      assert plot.margins == %{
        left: 70,
        top: 55,
        right: 10,
        bottom: 70
      }
    end
  end
    
  describe "axis_labels/3" do
    setup context do
      %{plot: Plot.axis_labels(context.plot, "X Side", "Y Side")}
    end

    test "sets x- and y-axis labels", %{plot: plot} do
      assert plot.x_label == "X Side"
      assert plot.y_label == "Y Side"
    end

    test "recalculates margins", %{plot: plot} do
      assert plot.margins == %{
        left: 90,
        top: 10,
        right: 10,
        bottom: 90
      }
    end
  end

  describe "size/3" do
    setup context do
      %{plot: Plot.size(context.plot, 200, 300)}
    end

    test "sets width and height", %{plot: plot} do
      assert plot.width == 200
      assert plot.height == 300
    end

    # TODO
    # Plot.size/3 calls calculate_margins/1 internally but the plot
    # dimensions are not an input to the margin calculation so it's
    # not clear why.
    test "doesn't affect margins", %{plot: plot} do
      assert plot.margins == %{
        left: 70,
        top: 10,
        right: 10,
        bottom: 70
      }
    end
  end

  describe "to_svg/1" do
    test "renders plot svg", %{plot: plot} do
      {:safe, svg} =
        Plot.titles(plot, "The Title", "The Sub")
        |> Plot.axis_labels("X Side", "Y Side")
        |> Plot.plot_options(%{legend_setting: :legend_right})
        |> Plot.to_svg()
      
      svg =
        IO.chardata_to_string(svg) 
        |> xpath(~x"/svg", 
             viewbox: ~x"./@viewBox"s,
             title: [
               ~x"./text[@class='exc-title']",
               text: ~x"./text()"s,
               x: ~x"./@x"s,
               y: ~x"./@y"s
             ],
             subtitle: [
               ~x".//text[@class='exc-subtitle'][1]",
               text: ~x"./text()"s,
               x: ~x"./@x"s,
               y: ~x"./@y"s
             ],
             x_axis_label: [
               ~x".//text[@class='exc-subtitle'][2]",
               text: ~x"./text()"s,
               x: ~x"./@x"s,
               y: ~x"./@y"s
             ],
             y_axis_label: [
               ~x".//text[@class='exc-subtitle'][3]",
               text: ~x"./text()"s,
               x: ~x"./@x"s,
               y: ~x"./@y"s
             ],
             legend_transform: ~x"./g[last()]/@transform"s
           )

      # Only test elements that are not rendered ultimately rendered 
      # by PlotContent.to_svg/1 or PlotContent.get_svg_legend/1
      assert svg.viewbox == "0 0 150 200"
      assert svg.title == %{text: "The Title", x: "65.0", y: "20"}
      assert svg.subtitle == %{text: "The Sub", x: "65.0", y: "35"}
      assert svg.x_axis_label == %{text: "X Side", x: "65.0", y: "180"}
      assert svg.y_axis_label == %{text: "Y Side", x: "-82.5", y: "20"}
      assert svg.y_axis_label == %{text: "Y Side", x: "-82.5", y: "20"}
      assert svg.legend_transform == "translate(50, 65)"
    end
  end
end
