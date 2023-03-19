defmodule ContexGalleryBarChartTest do
  use ExUnit.Case
  import Contex.Gallery.Sample, only: [safely_evaluate_svg: 1]

  describe "Assert validity of generated SVG" do
    test "All of them" do
      files = [
        "bar_charts_log_stacked.sample",
        "bar_charts_log_stacked_auto_domain.sample",
        "bar_charts_log_stacked_empty.sample"
      ]

      path = "lib/chart/gallery"
      aliases = "00_aliases.sample"

      files
      |> Enum.map(fn f ->
        assert {:ok, _source_code, svg, _time} =
                 safely_evaluate_svg(["#{path}/#{aliases}", "#{path}/#{f}"])

        assert {:ok, document} = Floki.parse_document(svg)
        # IO.puts(inspect(document))
      end)
    end
  end
end
