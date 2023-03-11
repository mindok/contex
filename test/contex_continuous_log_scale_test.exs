defmodule ContinuousLogScaleTest do
  # mix test test/contex_continuous_log_scale_test.exs
  use ExUnit.Case

  alias Contex.ContinuousLogScale

  describe "Build ContinuousLogScale" do
    test "defaults" do
      assert %Contex.ContinuousLogScale{
               custom_tick_formatter: nil,
               domain: {0.0, 1.0},
               interval_count: 10,
               linear_range: nil,
               log_base_fn: _,
               negative_numbers: :clip,
               range: nil,
               #
               nice_domain: {0.0, 1.0},
               display_decimals: 3,
               interval_size: 0.1
             } = ContinuousLogScale.new()
    end
  end

  describe "Compute log_value" do
    test "mode :mask, no linear" do
      f = fn v -> ContinuousLogScale.log_value(v, &:math.log2/1, :mask, nil) end

      [
        {"Negative", -3, 0},
        {"Zero", 0, 0},
        {"Positive A", 2, 1},
        {"Positive B", 8, 3}
      ]
      |> Enum.map(fn c -> test_case(f, c) end)
    end

    test "mode :mask, linear part" do
      f = fn v -> ContinuousLogScale.log_value(v, &:math.log2/1, :mask, 1.0) end

      [
        {"Negative, outside linear", -3, 0},
        {"Negative, within linear", -0.5, 0},
        {"Zero", 0, 0},
        {"Positive, within linear", 0.3, 0.3},
        {"Positive, outside linear", 2, 1}
      ]
      |> Enum.map(fn c -> test_case(f, c) end)
    end

    test "mode :sym, no linear" do
      f = fn v -> ContinuousLogScale.log_value(v, &:math.log2/1, :sym, nil) end

      [
        {"Negative A", -8, -3},
        {"Negative B", -2, -1},
        {"Zero", 0, 0},
        {"Positive A", 2, 1},
        {"Positive B", 8, 3}
      ]
      |> Enum.map(fn c -> test_case(f, c) end)
    end

    test "mode :sym, linear part" do
      f = fn v -> ContinuousLogScale.log_value(v, &:math.log2/1, :sym, 1.0) end

      [
        {"Negative, outside linear", -8, -3},
        {"Negative, within linear", -0.5, -0.5},
        {"Zero", 0, 0},
        {"Positive, within linear", 0.3, 0.3},
        {"Positive, outside linear", 2, 1}
      ]
      |> Enum.map(fn c -> test_case(f, c) end)
    end
  end

  test "Write Point Plot" do
    alias Contex.Plot
    alias Contex.PointPlot
    alias Contex.BarChart
    alias Contex.Dataset

    data =
      -200..200
      |> Enum.map(fn v -> {v / 10.0, v / 10.0} end)

    ds = Dataset.new(data, ["x", "y"])

    options = [
      mapping: %{x_col: "x", y_cols: ["y"]},
      data_labels: true,
      orientation: :vertical,
      custom_y_scale:
        ContinuousLogScale.new(domain: {-20, 20}, negative_numbers: :mask, linear_range: 1),
      colour_palette: ["ff9838", "fdae53", "fbc26f", "fad48e", "fbe5af", "fff5d1"]
    ]

    plot =
      Plot.new(ds, PointPlot, 500, 400, options)
      |> Plot.titles("zeb", "ra")
      |> Plot.axis_labels("x", "y")

    # |> Plot.plot_options(%{})

    # plot_html("Linear plot", plot)
  end

  test "Write Bar Plot" do
    alias Contex.Plot
    alias Contex.PointPlot
    alias Contex.BarChart
    alias Contex.Dataset

    data = [{"a", 10, 5}, {"b", 20, 10}, {"c", 3, 7}]
    ds = Dataset.new(data, ["x", "y1", "y2"])

    options = [
      mapping: %{category_col: "x", value_cols: ["y1", "y2"]},
      data_labels: true,
      orientation: :horizontal,
      custom_value_scale: ContinuousLogScale.new(negative_numbers: :mask, linear_range: 1),
      colour_palette: ["ff9838", "fdae53", "fbc26f", "fad48e", "fbe5af", "fff5d1"]
    ]

    plot =
      Plot.new(ds, BarChart, 500, 400, options)
      |> Plot.titles("zeb", "ra")
      |> Plot.axis_labels("x", "y")

    # |> Plot.plot_options(%{})

    plot_html("Bar plot", plot)
  end

  def test_case(function, {case_name, input_val, expected_output}) do
    result = function.(input_val)
    error = abs(result - expected_output)

    assert error < 0.001,
           "Case #{case_name} - For #{input_val} expected #{expected_output} but got #{result} "
  end

  def plot_html(title, plot) do
    alias Contex.Plot

    {:safe, v} = Plot.to_svg(plot)
    svg = Enum.join(v, " ")

    {:ok, file} = File.open("doc/hello.html", [:write])
    IO.binwrite(file, "<h1>#{title}</h1>#{svg}")
    File.close(file)
  end
end
