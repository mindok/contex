defmodule ContexGalleryPointPlotTest do
  use ExUnit.Case

  describe "Assert validity of generated SVG" do
    test "All of them" do
      files = [
        "point_plots_log_masked.sample",
        "point_plots_log_masked_autorange.sample",
        "point_plots_log_masked_linear.sample",
        "point_plots_log_symmetric.sample"
      ]

      Commons.test_svg_is_well_formed(files)
    end
  end
end
