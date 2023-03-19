defmodule ContexTimeScaleTest do
  use ExUnit.Case

  alias Contex.{Scale, TimeScale}

  defp create_timescale({d_min, d_max} = _domain, {r_min, r_max} = _range) do
    TimeScale.new()
    |> Scale.set_range(r_min, r_max)
    |> TimeScale.domain(d_min, d_max)
  end

  defp asset_datetimelists_equal(list1, list2) do
    Enum.zip(list1, list2)
    |> Enum.each(fn {dt1, dt2} ->
      assert NaiveDateTime.compare(dt1, dt2) == :eq
    end)
  end

  describe "validity tests" do
    test "Create with non-date domain" do
      assert_raise FunctionClauseError, fn ->
        _scale = create_timescale({"fred", 10.0}, {0.0, 100.0})
      end
    end

    test "Create with non-numeric range" do
      assert_raise FunctionClauseError, fn ->
        _scale =
          create_timescale(
            {~U[2015-01-13 13:00:00.056Z], ~U[2015-01-13 13:00:05.000Z]},
            {"0.0", 100.0}
          )
      end
    end

    test "Mixed DateTime" do
      assert_raise FunctionClauseError, fn ->
        _scale =
          create_timescale(
            {~N[2015-01-13 13:00:00.056], ~U[2015-01-13 13:00:05.000Z]},
            {0.0, 100.0}
          )
      end
    end
  end

  describe "ticks" do
    test "for 5sec timescale" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:00:00.056Z], ~U[2015-01-13 13:00:05.000Z]},
          {0.0, 100.0}
        )

      expected_ticks = [
        ~U[2015-01-13 13:00:00Z],
        ~U[2015-01-13 13:00:01Z],
        ~U[2015-01-13 13:00:02Z],
        ~U[2015-01-13 13:00:03Z],
        ~U[2015-01-13 13:00:04Z],
        ~U[2015-01-13 13:00:05Z]
      ]

      asset_datetimelists_equal(expected_ticks, Scale.ticks_domain(scale))
    end

    test "for 5sec timescale - NaiveDateTime" do
      scale =
        create_timescale({~N[2015-01-13 13:00:00.056], ~N[2015-01-13 13:00:05.000]}, {0.0, 100.0})

      expected_ticks = [
        ~N[2015-01-13 13:00:00],
        ~N[2015-01-13 13:00:01],
        ~N[2015-01-13 13:00:02],
        ~N[2015-01-13 13:00:03],
        ~N[2015-01-13 13:00:04],
        ~N[2015-01-13 13:00:05]
      ]

      asset_datetimelists_equal(expected_ticks, Scale.ticks_domain(scale))
    end

    test "for 10 day timescale" do
      scale =
        create_timescale(
          {~U[2015-01-01 13:00:00.056Z], ~U[2015-01-10 13:00:05.000Z]},
          {0.0, 100.0}
        )

      expected_ticks = [
        ~U[2015-01-01 00:00:00Z],
        ~U[2015-01-02 00:00:00Z],
        ~U[2015-01-03 00:00:00Z],
        ~U[2015-01-04 00:00:00Z],
        ~U[2015-01-05 00:00:00Z],
        ~U[2015-01-06 00:00:00Z],
        ~U[2015-01-07 00:00:00Z],
        ~U[2015-01-08 00:00:00Z],
        ~U[2015-01-09 00:00:00Z],
        ~U[2015-01-10 00:00:00Z],
        ~U[2015-01-11 00:00:00Z]
      ]

      asset_datetimelists_equal(expected_ticks, Scale.ticks_domain(scale))
    end

    test "for 10 day timescale (end of month start)" do
      scale =
        create_timescale(
          {~U[2015-11-30 13:00:00.056Z], ~U[2015-12-13 13:00:05.000Z]},
          {0.0, 100.0}
        )

      expected_ticks = [
        ~U[2015-11-30 00:00:00Z],
        ~U[2015-12-02 00:00:00Z],
        ~U[2015-12-04 00:00:00Z],
        ~U[2015-12-06 00:00:00Z],
        ~U[2015-12-08 00:00:00Z],
        ~U[2015-12-10 00:00:00Z],
        ~U[2015-12-12 00:00:00Z],
        ~U[2015-12-14 00:00:00Z]
      ]

      asset_datetimelists_equal(expected_ticks, Scale.ticks_domain(scale))
    end

    test "for 10 day timescale - 8 intervals" do
      scale =
        create_timescale(
          {~U[2015-01-01 13:00:00.056Z], ~U[2015-01-10 13:00:05.000Z]},
          {0.0, 100.0}
        )

      scale = TimeScale.interval_count(scale, 8)

      expected_ticks = [
        ~U[2015-01-01 00:00:00Z],
        ~U[2015-01-03 00:00:00Z],
        ~U[2015-01-05 00:00:00Z],
        ~U[2015-01-07 00:00:00Z],
        ~U[2015-01-09 00:00:00Z],
        ~U[2015-01-11 00:00:00Z]
      ]

      asset_datetimelists_equal(expected_ticks, Scale.ticks_domain(scale))
    end

    test "for 10 month timescale" do
      scale =
        create_timescale(
          {~U[2015-01-01 13:00:00.056Z], ~U[2015-09-28 13:00:05.000Z]},
          {0.0, 100.0}
        )

      expected_ticks = [
        ~U[2015-01-01 00:00:00Z],
        ~U[2015-02-01 00:00:00Z],
        ~U[2015-03-01 00:00:00Z],
        ~U[2015-04-01 00:00:00Z],
        ~U[2015-05-01 00:00:00Z],
        ~U[2015-06-01 00:00:00Z],
        ~U[2015-07-01 00:00:00Z],
        ~U[2015-08-01 00:00:00Z],
        ~U[2015-09-01 00:00:00Z],
        ~U[2015-10-01 00:00:00Z]
      ]

      assert expected_ticks == Scale.ticks_domain(scale)
    end

    test "for 10 month timescale - 8 intervals" do
      scale =
        create_timescale(
          {~U[2015-01-01 13:00:00.056Z], ~U[2015-09-28 13:00:05.000Z]},
          {0.0, 100.0}
        )

      scale = TimeScale.interval_count(scale, 8)

      expected_ticks = [
        ~U[2014-12-31 00:00:00Z],
        ~U[2015-03-31 00:00:00Z],
        ~U[2015-06-30 00:00:00Z],
        ~U[2015-09-30 00:00:00Z]
      ]

      assert expected_ticks == Scale.ticks_domain(scale)
    end

    test "for 10 month timescale mid month start and end" do
      scale =
        create_timescale(
          {~U[2015-01-15 13:00:00.056Z], ~U[2015-09-15 13:00:05.000Z]},
          {0.0, 100.0}
        )

      expected_ticks = [
        ~U[2015-01-01 00:00:00Z],
        ~U[2015-02-01 00:00:00Z],
        ~U[2015-03-01 00:00:00Z],
        ~U[2015-04-01 00:00:00Z],
        ~U[2015-05-01 00:00:00Z],
        ~U[2015-06-01 00:00:00Z],
        ~U[2015-07-01 00:00:00Z],
        ~U[2015-08-01 00:00:00Z],
        ~U[2015-09-01 00:00:00Z],
        ~U[2015-10-01 00:00:00Z]
      ]

      assert expected_ticks == Scale.ticks_domain(scale)
    end

    test "24month timescale aligns to quarter end" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:07:00.000Z], ~U[2017-01-13 13:17:00.000Z]},
          {0.0, 100.0}
        )

      expected_ticks = [
        ~U[2014-12-31 00:00:00Z],
        ~U[2015-03-31 00:00:00Z],
        ~U[2015-06-30 00:00:00Z],
        ~U[2015-09-30 00:00:00Z],
        ~U[2015-12-31 00:00:00Z],
        ~U[2016-03-31 00:00:00Z],
        ~U[2016-06-30 00:00:00Z],
        ~U[2016-09-30 00:00:00Z],
        ~U[2016-12-31 00:00:00Z],
        ~U[2017-03-31 00:00:00Z]
      ]

      assert expected_ticks == Scale.ticks_domain(scale)
    end
  end

  describe "domain to range functions" do
    test "transformations 5sec timescale" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:00:00.056Z], ~U[2015-01-13 13:00:05.000Z]},
          {0.0, 100.0}
        )

      xform_fn = Scale.domain_to_range_fn(scale)

      assert 20.0 == xform_fn.(~U[2015-01-13 13:00:01Z])
      assert 20.0 == Scale.domain_to_range(scale, ~U[2015-01-13 13:00:01Z])
    end

    test "transformations 5sec timescale - extrapolation beyond range" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:00:00.056Z], ~U[2015-01-13 13:00:05.000Z]},
          {0.0, 100.0}
        )

      xform_fn = Scale.domain_to_range_fn(scale)

      assert 200.0 == xform_fn.(~U[2015-01-13 13:00:10Z])
      assert 200.0 == Scale.domain_to_range(scale, ~U[2015-01-13 13:00:10Z])

      assert -20.0 == xform_fn.(~U[2015-01-13 12:59:59Z])
    end

    test "transformations 10 day timescale" do
      scale =
        create_timescale(
          {~U[2015-01-01 13:00:00.056Z], ~U[2015-01-10 13:00:05.000Z]},
          {0.0, 100.0}
        )

      xform_fn = Scale.domain_to_range_fn(scale)

      assert 15.0 == xform_fn.(~U[2015-01-02 12:00:00Z])
    end
  end

  describe "formatting" do
    test "5sec timescale shows mins and secs" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:00:00.056Z], ~U[2015-01-13 13:00:05.000Z]},
          {0.0, 100.0}
        )

      expected_formatted_ticks = ["00:00", "00:01", "00:02", "00:03", "00:04", "00:05"]

      actual_formatted_ticks =
        scale
        |> Scale.ticks_domain()
        |> Enum.map(fn tick -> Scale.get_formatted_tick(scale, tick) end)

      assert expected_formatted_ticks == actual_formatted_ticks
    end

    test "5min timescale shows mins and secs" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:12:00.000Z], ~U[2015-01-13 13:17:00.000Z]},
          {0.0, 100.0}
        )

      expected_formatted_ticks = [
        "12:00",
        "12:30",
        "13:00",
        "13:30",
        "14:00",
        "14:30",
        "15:00",
        "15:30",
        "16:00",
        "16:30",
        "17:00"
      ]

      actual_formatted_ticks =
        scale
        |> Scale.ticks_domain()
        |> Enum.map(fn tick -> Scale.get_formatted_tick(scale, tick) end)

      assert expected_formatted_ticks == actual_formatted_ticks
    end

    test "10min timescale shows hrs, mins and secs" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:07:00.000Z], ~U[2015-01-13 13:17:00.000Z]},
          {0.0, 100.0}
        )

      expected_formatted_ticks = [
        "13:07:00",
        "13:08:00",
        "13:09:00",
        "13:10:00",
        "13:11:00",
        "13:12:00",
        "13:13:00",
        "13:14:00",
        "13:15:00",
        "13:16:00",
        "13:17:00"
      ]

      actual_formatted_ticks =
        scale
        |> Scale.ticks_domain()
        |> Enum.map(fn tick -> Scale.get_formatted_tick(scale, tick) end)

      assert expected_formatted_ticks == actual_formatted_ticks
    end

    test "24hr timescale shows days & hrs" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:07:00.000Z], ~U[2015-01-14 13:17:00.000Z]},
          {0.0, 100.0}
        )

      expected_formatted_ticks = [
        "13 Jan 12:00",
        "13 Jan 15:00",
        "13 Jan 18:00",
        "13 Jan 21:00",
        "14 Jan 00:00",
        "14 Jan 03:00",
        "14 Jan 06:00",
        "14 Jan 09:00",
        "14 Jan 12:00",
        "14 Jan 15:00"
      ]

      actual_formatted_ticks =
        scale
        |> Scale.ticks_domain()
        |> Enum.map(fn tick -> Scale.get_formatted_tick(scale, tick) end)

      assert expected_formatted_ticks == actual_formatted_ticks
    end

    test "24month timescale shows months and years, displayed as quarters" do
      scale =
        create_timescale(
          {~U[2015-01-13 13:07:00.000Z], ~U[2017-01-13 13:17:00.000Z]},
          {0.0, 100.0}
        )

      expected_formatted_ticks = [
        "Dec 2014",
        "Mar 2015",
        "Jun 2015",
        "Sep 2015",
        "Dec 2015",
        "Mar 2016",
        "Jun 2016",
        "Sep 2016",
        "Dec 2016",
        "Mar 2017"
      ]

      actual_formatted_ticks =
        scale
        |> Scale.ticks_domain()
        |> Enum.map(fn tick -> Scale.get_formatted_tick(scale, tick) end)

      assert expected_formatted_ticks == actual_formatted_ticks
    end
  end
end
