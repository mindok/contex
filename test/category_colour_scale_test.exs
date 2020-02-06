defmodule ContexCategoryColourScaleTest do
  use ExUnit.Case

  alias Contex.CategoryColourScale

  test "Cardinal Colour Scale" do
    values = ["Fred", "Bob", "Fred", "Bill"]
    palette = ["Red", "Green", "Blue"]

    scale = CategoryColourScale.new(values) |> CategoryColourScale.set_palette(palette)

    default_colour = CategoryColourScale.get_default_colour(scale)

    assert CategoryColourScale.colour_for_value(scale, "Fred") == "Red"
    assert CategoryColourScale.colour_for_value(scale, "Bill") == "Blue"
    assert CategoryColourScale.colour_for_value(scale, "Barney") == default_colour

    scale = CategoryColourScale.set_palette(scale, :pastel1)
    assert CategoryColourScale.colour_for_value(scale, "Fred") == "fbb4ae"
    assert CategoryColourScale.colour_for_value(scale, "Bill") == "ccebc5"
    assert CategoryColourScale.colour_for_value(scale, "Barney") == default_colour
  end
end
