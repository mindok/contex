defmodule ScaleUtilsTest do
  # mix test test/contex_continuous_log_scale_test.exs
  use ExUnit.Case

  alias Contex.ScaleUtils

  describe "Resize/rescale" do
    test "with fixed intervals" do
      assert %{
               display_decimals: 0,
               ticks: [0.0, 20.0, 40.0, 60.0, 80.0, 100.0],
               nice_domain: {0.0, 100.0}
             } =
               ScaleUtils.compute_nice_settings(
                 0,
                 100,
                 nil,
                 5
               )
    end

    test "with interval set" do
      assert %{
               display_decimals: 0,
               ticks: [0, 10, 50],
               nice_domain: {0.0, 80.0}
             } =
               ScaleUtils.compute_nice_settings(
                 0,
                 80,
                 [0, 10, 50, 90, 130],
                 5
               )
    end
  end
end
