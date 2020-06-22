defmodule Remit.Utils do
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
    # Reference: https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html
    datetime |> to_tz() |> Timex.format!("{WDshort} {D} {Mshort} at {h24}:{m}")
  end

  def format_time(datetime) do
    # Reference: https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html
    datetime |> to_tz() |> Timex.format!("at {h24}:{m}")
  end

  def format_date(date) do
    date |> Timex.format!("{WDshort} {D} {Mshort}")
  end

  def usernames_from_email(email) do
    email                 # foo+bar+baz@example.com
    |> String.split("@")  # foo+bar+baz, example.com
    |> hd                 # foo+bar+baz
    |> String.split("+")  # foo, bar, baz
    |> Enum.drop(1)       # bar, baz
  end

  # Private

  defp to_tz(datetime) do
    DateTime.shift_zone!(datetime, @timezone)
  end
end
