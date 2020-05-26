defmodule Remit.Utils do
  @timezone "Europe/Stockholm"

  def normalize_string(nil), do: nil

  def normalize_string(string) do
    string = String.trim(string)
    if string == "", do: nil, else: string
  end

  def format_datetime(datetime) do
    # Reference: https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html
    datetime
    |> Timex.Timezone.convert(@timezone)
    |> Timex.format!("{WDshort} {D} {Mshort} at {h24}:{m}")
  end
end
