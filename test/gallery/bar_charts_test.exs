defmodule ContexGalleryBarChartTest do
  use ExUnit.Case

  describe "Assert validity of generated SVG" do
    test "All of them" do
      files = [
        "bar_charts_plain.sample",
        "bar_charts_plain_horizontal.sample",
        "bar_charts_plain_stacked.sample",
        "bar_charts_log_stacked.sample",
        "bar_charts_log_stacked_auto_domain.sample"
      ]

      Commons.test_svg_is_well_formed(files)
    end
  end
end
