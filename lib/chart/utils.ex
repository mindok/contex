defmodule Contex.Utils do
  @moduledoc false

  def date_compare(%DateTime{}=a, %DateTime{}=b) do
    DateTime.compare(a, b)
  end
  def date_compare(%NaiveDateTime{}=a, %NaiveDateTime{}=b) do
    NaiveDateTime.compare(a, b)
  end

  defp date_min(a, b), do: if date_compare(a, b) == :lt, do: a, else: b
  defp date_max(a, b), do: if date_compare(a, b) != :lt, do: a, else: b

  def safe_min(nil, nil), do: nil
  def safe_min(nil, b), do: b
  def safe_min(a, nil), do: a
  def safe_min(%DateTime{}=a, %DateTime{}=b), do: date_min(a, b)
  def safe_min(%NaiveDateTime{}=a, %NaiveDateTime{}=b), do: date_min(a, b)
  def safe_min(a, b) when is_number(a) and is_number(b), do: min(a,b)
  def safe_min(_, _), do: nil

  def safe_max(nil, nil), do: nil
  def safe_max(nil, b), do: b
  def safe_max(a, nil), do: a
  def safe_max(%DateTime{}=a, %DateTime{}=b), do: date_max(a, b)
  def safe_max(%NaiveDateTime{}=a, %NaiveDateTime{}=b), do: date_max(a, b)
  def safe_max(a, b) when is_number(a) and is_number(b), do: max(a,b)
  def safe_max(_, _), do: nil

  #def safe_min(x, y), do: safe_combine(x, y, fn x, y -> min(x, y) end)
  #def safe_max(x, y), do: safe_combine(x, y, fn x, y -> max(x, y) end)

  def safe_add(x, y), do: safe_combine(x, y, fn x, y -> x + y end)

  defp safe_combine(x, y, combiner) when is_number(x) and is_number(y), do: combiner.(x, y)
  defp safe_combine(x, _, _) when is_number(x), do: x
  defp safe_combine(_, y, _) when is_number(y), do: y
  defp safe_combine(_, _, _), do: nil

  def fixup_value_range({min, max}) when min == max and max > 0, do: {0, max}
  def fixup_value_range({min, max}) when min == max and max < 0, do: {max, 0}
  def fixup_value_range({min, max}), do: {min, max}

end
