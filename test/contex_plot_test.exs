defmodule ContexPlotTest do
  use ExUnit.Case

  alias Contex.{Plot, Dataset, PointPlot, BarChart}
  import SweetXml

  setup do
    plot =
      Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}], ["aa", "bb", "cccc", "d"])
      |> PointPlot.new()

    plot = Plot.new(150, 200, plot)
    %{plot: plot}
  end

  describe "new/5" do
    test "returns a Plot struct with default options and margins" do
      plot =
        Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}], ["aa", "bb", "cccc", "d"])
        |> Plot.new(PointPlot, 150, 200)

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

    test "Sets orientation on BarChart" do
      plot =
        Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}], ["aa", "bb", "cccc", "d"])
        |> Plot.new(BarChart, 150, 200, orientation: :horizontal)

      assert plot.plot_content.orientation == :horizontal
    end

    test "returns a Plot struct using assigned attributes" do
      plot =
        Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}], ["aa", "bb", "cccc", "d"])
        |> Plot.new(
          PointPlot,
          150,
          200,
          title: "Title",
          x_label: "X Label",
          legend_setting: :legend_right
        )

      assert plot.title == "Title"
      assert plot.x_label == "X Label"
      assert plot.plot_options.legend_setting == :legend_right
      assert plot.margins == %{
        left: 70,
        top: 40,
        right: 110,
        bottom: 90
      }
    end
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

  describe "dataset/3" do
    test "given two lists updates the dataset and headers", %{plot: plot} do
      plot = Plot.dataset(plot, [{1,2}, {3,4}], ["x", "y"])
      assert plot.plot_content.dataset.data == [{1, 2}, {3, 4}]
      assert plot.plot_content.dataset.headers == ["x", "y"]
    end
  end

  describe "dataset/2" do
    test "given a Dataset updates the dataset", %{plot: plot} do
      dataset = Dataset.new([{1,2}, {3,4}],["first", "second"])
      plot = Plot.dataset(plot, dataset)
      assert plot.plot_content.dataset.headers == ["first", "second"]
      assert plot.plot_content.dataset.data == [{1, 2}, {3, 4}]
    end

    test "given one list updates the dataset, preserving headers", %{plot: plot} do
      headers = plot.plot_content.dataset.headers
      plot = Plot.dataset(plot, [{1,2}, {3,4}])
      assert plot.plot_content.dataset.data == [{1, 2}, {3, 4}]
      assert plot.plot_content.dataset.headers == headers
    end
  end

  describe "attributes/2" do
    test "updates provided attributes", %{plot: plot} do
      plot = Plot.attributes(plot, title: "Title", x_label: "X Label", legend_setting: :legend_right)

      assert plot.title == "Title"
      assert plot.x_label == "X Label"
      assert plot.plot_options.legend_setting == :legend_right
    end

    test "recalculates margins", %{plot: plot} do
      plot = Plot.attributes(plot, title: "Title", x_label: "X Label", legend_setting: :legend_right)

      assert plot.margins == %{
        left: 70,
        top: 40,
        right: 110,
        bottom: 90
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

    test "raises error when category missing" do
      test_data =
        Dataset.new([["aa", 2, 3, 4], ["bb", 5, 6, 4]], [
          "Category",
          "Series 1",
          "Series 2",
          "Other Series"
        ])

      plot_content =
        BarChart.new(test_data)
        |> BarChart.set_val_col_names(["Series 1", "Series 2", "Wrong Name"])

      plot = Plot.new(500, 400, plot_content)

      plot =
        Plot.titles(plot, "The Title", "The Sub")
        |> Plot.axis_labels("X Side", "Y Side")
        |> Plot.plot_options(%{legend_setting: :legend_right})

      assert_raise(
        RuntimeError,
        "Missing header \"Wrong Name\"",
        fn ->
          Plot.to_svg(plot)
        end
      )
    end

    test "renders integer data as bar labels" do
      test_data =
        Dataset.new([["aa", 42, 8.222222222]], [
          "Category",
          "Series 1",
          "Series 2"
        ])

      plot_content =
        BarChart.new(test_data)
        |> BarChart.set_val_col_names(["Series 1", "Series 2"])

      plot = Plot.new(500, 400, plot_content)

      assert {:safe, svg} =
               Plot.titles(plot, "The Title", "The Sub")
               |> Plot.to_svg()

      results =
        svg
        |> IO.chardata_to_string()
        |> xpath(~x"/svg",
          barlabels: [
            ~x".//text[@class='exc-barlabel-in']"l,
            text: ~x"./text()"s
          ]
        )

      assert results.barlabels == [%{text: "42"}, %{text: "8.2"}]
    end
  end
end
