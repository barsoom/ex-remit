defmodule Gravatar do
  def url(email) do
    # https://en.gravatar.com/site/implement/images/
    "https://www.gravatar.com/avatar/" <> hash(email) <> "?d=monsterid"
  end

  defp hash(nil), do: hash("")
  defp hash(email) do
    :crypto.hash(:md5, email)
    |> Base.encode16(case: :lower)
  end
end
