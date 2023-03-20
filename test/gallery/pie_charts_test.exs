defmodule ContexGalleryPieChartsTest do
  use ExUnit.Case

  describe "Assert validity of generated SVG" do
    test "All of them" do
      files = [
        "pie_charts_plain.sample"
      ]

      Commons.test_svg_is_well_formed(files)
    end
  end
end
