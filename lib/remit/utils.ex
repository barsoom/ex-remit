defmodule Remit.Utils do
  def normalize_string(nil), do: nil
  def normalize_string(string) do
    string = String.trim(string)
    if string == "", do: nil, else: string
  end
end
