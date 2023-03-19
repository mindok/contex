defmodule ContinuousLogScaleTest do
  # mix test test/contex_continuous_log_scale_test.exs
  use ExUnit.Case

  alias Contex.ContinuousLogScale
  alias Contex.Dataset

  describe "Build ContinuousLogScale" do
    test "defaults" do
      assert %Contex.ContinuousLogScale{
               custom_tick_formatter: nil,
               domain: {0.0, 1.0},
               tick_positions: [
                 0.0,
                 0.1,
                 0.2,
                 _,
                 _,
                 _,
                 _,
                 _,
                 0.8,
                 0.9,
                 1.0
               ],
               interval_count: 10,
               linear_range: nil,
               log_base_fn: _,
               negative_numbers: :clip,
               range: nil,
               #
               nice_domain: {0.0, 1.0},
               display_decimals: 3
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

  describe "Get extents out of a dataset" do
    def ds(),
      do:
        Dataset.new(
          [{"a", 10, 5}, {"b", 20, 10}, {"c", 3, 7}],
          ["x", "y1", "y2"]
        )

    test "Explicit domain" do
      assert {7, 9} = ContinuousLogScale.get_domain({7, 9}, ds(), "x")
    end

    test "Use dataset" do
      assert {3, 20} = ContinuousLogScale.get_domain(:notfound, ds(), "y1")

      assert {5, 10} = ContinuousLogScale.get_domain(:notfound, ds(), "y2")
    end

    test "specific dataset 1" do
      series_cols = ["b0", "b1", "b2", "b3", "b4"]

      data = [
        %{
          "b0" => 10.4333,
          "b1" => 1.4834000000000014,
          "b2" => 2.0332999999999988,
          "b3" => 16.7833,
          "b4" => 265.40000000000003,
          "lbl" => "2023-03-09"
        },
        %{
          "b0" => 9.8667,
          "b1" => 1.5665999999999993,
          "b2" => 4.58340000000000,
          "b3" => 83.0333,
          "b4" => 359.15,
          "lbl" => "2023-03-08"
        },
        %{
          "b0" => 7.8333,
          "b1" => 2.9166999999999996,
          "b2" => 1.4666999999999994,
          "b3" => 9.600000000000001,
          "b4" => 379.2833,
          "lbl" => "2023-03-07"
        }
      ]

      test_dataset = Dataset.new(data, ["lbl" | series_cols])

      assert {1.4666999999999994, 379.2833} =
               ContinuousLogScale.get_domain(:notfound, test_dataset, series_cols)
    end
  end

  def test_case(function, {case_name, input_val, expected_output}) do
    result = function.(input_val)
    error = abs(result - expected_output)

    assert error < 0.001,
           "Case #{case_name} - For #{input_val} expected #{expected_output} but got #{result} "
  end
end
