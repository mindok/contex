defmodule ContexLegendTest do
  use ExUnit.Case

  alias Contex.{Dataset, PointPlot}
  import SweetXml

  describe "to_svg/2" do
    test "returns properly formatted legend" do
      plot =
        Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}], ["aa", "bb", "cccc", "d"])
        |> PointPlot.new()

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
end
