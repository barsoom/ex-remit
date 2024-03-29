defmodule Remit.Utils do
  @moduledoc false
  @timezone "Europe/Stockholm"

  def normalize_string(nil), do: nil

  def normalize_string(string) do
    string = String.trim(string)
    if string == "", do: nil, else: string
  end

  def date_time_from_iso8601!(raw_datetime) do
    {:ok, datetime, _offset} = DateTime.from_iso8601(raw_datetime)
    ensure_usec(datetime)
  end

  def ensure_usec(%DateTime{microsecond: {0, 0}} = datetime), do: %{datetime | microsecond: {0, 6}}
  def ensure_usec(%DateTime{} = datetime), do: datetime

  def to_date(datetime) do
    datetime |> to_tz() |> DateTime.to_date()
  end

  def format_datetime(datetime) do
    # Reference: https://hexdocs.pm/elixir/Calendar.html#strftime/3
    datetime |> to_tz() |> Calendar.strftime("%a %d %b at %H:%M")
  end

  def format_time(datetime) do
    # Reference: https://hexdocs.pm/elixir/Calendar.html#strftime/3
    datetime |> to_tz() |> Calendar.strftime("at %H:%M")
  end

  def format_date(date) do
    # Reference: https://hexdocs.pm/elixir/Calendar.html#strftime/3
    date |> Calendar.strftime("%a %d %b")
  end

  def usernames_from_email(email) do
    # foo+bar+baz@example.com
    email
    # foo+bar+baz, example.com
    |> String.split("@")
    # foo+bar+baz
    |> hd
    # foo, bar, baz
    |> String.split("+")
    # bar, baz
    |> Enum.drop(1)
  end

  # Private

  defp to_tz(datetime) do
    DateTime.shift_zone!(datetime, @timezone)
  end
end
