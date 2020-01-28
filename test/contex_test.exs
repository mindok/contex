defmodule ContexTest do
  use ExUnit.Case

  alias Contex.Dataset

  doctest Contex
  doctest Contex.Dataset
  doctest Contex.OrdinalScale

  describe "Dataset tests" do
    test "Dataset column lookup" do
      dataset_nocols = Dataset.new([{1, 2, 3}, {4, 5, 6}, {-3, -2, -1}])
      dataset = Dataset.new(dataset_nocols.data, ["aa", "bb", "cccc"])

      assert Dataset.column_index(dataset, "bb") == 1
      assert Dataset.column_index(dataset, "bbb") == nil

      assert Dataset.column_index(dataset_nocols, "bb") == nil

      [row1 | _] = dataset_nocols.data

      assert Dataset.value(row1, 0) == 1
      assert Dataset.value(row1, 10) == nil

      assert Dataset.value(row1, Dataset.column_index(dataset, "cccc")) == 3

      assert Dataset.column_extents(dataset, "bb") == {-2, 5}
    end

    test "Dataset accessing nested list entries" do
      dataset_nocols = Dataset.new([[1, 2, 3], [4, 5, 6], [-3, -2, -1]])
      dataset = Dataset.new(dataset_nocols.data, ["aa", "bb", "cccc"])

      [row1 | _] = dataset_nocols.data

      assert Dataset.value(row1, 0) == 1
      assert Dataset.value(row1, 10) == nil

      assert Dataset.value(row1, Dataset.column_index(dataset, "cccc")) == 3

      assert Dataset.column_extents(dataset, "bb") == {-2, 5}
    end

  end

  describe "scales" do
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

end
