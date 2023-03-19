defmodule ContexGalleryPointPlotTest do
  use ExUnit.Case
  import Contex.Gallery.Sample, only: [safely_evaluate_svg: 1]

  describe "Assert validity of generated SVG" do
    test "All of them" do
      # ./lib/chart/gallery/bar_charts_log_stacked.sample
      # ./lib/chart/gallery/bar_charts_log_stacked_auto_domain.sample
      # ./lib/chart/gallery/bar_charts_log_stacked_empty.sample
      files = [
        "point_plots_log_masked.sample",
        "point_plots_log_masked_autorange.sample",
        "point_plots_log_masked_linear.sample",
        "point_plots_log_symmetric.sample"
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
